import Foundation

/// Cross-checks the journal against itself.
///
/// A header carries three redundant encodings of one fact: the weekday, the numeric date, and
/// the `delta` measuring the gap to the block above. They disagree often enough in real
/// history that reconciling them is a feature rather than a nicety -- and because there are
/// three, the two that agree identify which one is wrong. Usually that is the numeric date:
/// the weekday and the gap are lived, the digits are typed. Not always, though, so the
/// majority decides rather than a fixed assumption.
public enum Diagnostics {
    public static func analyze(_ document: Document) -> [Diagnostic] {
        analyze(document, blocks: document.blocks, lines: document.lines.indices)
    }

    /// The diagnostics for one span of lines.
    ///
    /// What the gutter needs, and all it has ever drawn: marks beside the text on screen.
    /// Answering for the whole journal in order to keep a screenful of it meant re-deriving
    /// every block on every keystroke, which is the cost this exists to avoid.
    ///
    /// The blocks either side of the span are still consulted -- a header's date is checked
    /// against its neighbours' deltas -- but their own diagnostics are not reported, because
    /// nothing was asked about them.
    public static func analyze(_ document: Document, lines range: Range<Int>) -> [Diagnostic] {
        analyze(document, blocks: document.blocks(intersecting: range), lines: range)
    }

    /// Computes `blocks` once and shares it. Each pass used to derive its own, which for a
    /// journal of any length was most of the cost of analyzing one.
    private static func analyze(
        _ document: Document, blocks: [Block], lines range: Range<Int>
    ) -> [Diagnostic] {
        var diagnostics = unrecognizedLines(document, in: range)
        diagnostics += dateDisagreements(document, blocks: blocks)
        diagnostics += deltaDisagreements(document, blocks: blocks)
        diagnostics += sectionOrderProblems(document, blocks: blocks)
        return diagnostics
            .filter { range.contains($0.lineIndex) }
            .sorted { $0.lineIndex < $1.lineIndex }
    }

    // MARK: - Unrecognized lines

    private static func unrecognizedLines(
        _ document: Document, in range: Range<Int>
    ) -> [Diagnostic] {
        range.clamped(to: document.lines.indices).compactMap { index in
            guard document.lines[index].kind == .unknown else { return nil }
            return Diagnostic(
                lineIndex: index,
                kind: .unrecognizedLine,
                reasoning: "This line is not a header, a section label, a delta, or an item. "
                    + "It is kept exactly as written."
            )
        }
    }

    // MARK: - Dates

    /// The evidence available about one block's header.
    private struct HeaderEvidence {
        var block: Block
        /// Gap to the newer block above, as claimed by this block's own delta.
        var claimedGapToNewer: Int?
        var newerDate: Date?
        /// Gap to the older block below, as claimed by *that* block's delta.
        var claimedGapToOlder: Int?
        var olderDate: Date?

        /// Whether a candidate date satisfies each delta that exists.
        func deltasAgree(with candidate: Date) -> Bool? {
            var checked = false
            if let claimedGapToNewer, let newerDate {
                checked = true
                guard JournalCalendar.days(from: candidate, to: newerDate) == claimedGapToNewer
                else { return false }
            }
            if let claimedGapToOlder, let olderDate {
                checked = true
                guard JournalCalendar.days(from: olderDate, to: candidate) == claimedGapToOlder
                else { return false }
            }
            return checked ? true : nil
        }
    }

    private static func dateDisagreements(
        _ document: Document, blocks: [Block]
    ) -> [Diagnostic] {
        blocks.indices.compactMap { index in
            let block = blocks[index]
            let evidence = HeaderEvidence(
                block: block,
                claimedGapToNewer: block.deltaAbove,
                newerDate: index > 0 ? blocks[index - 1].header.date : nil,
                claimedGapToOlder: index + 1 < blocks.count ? blocks[index + 1].deltaAbove : nil,
                olderDate: index + 1 < blocks.count ? blocks[index + 1].header.date : nil
            )
            return diagnose(evidence, in: document)
        }
    }

    private static func diagnose(_ evidence: HeaderEvidence, in document: Document) -> Diagnostic? {
        let block = evidence.block
        let header = block.header

        guard let statedDate = header.date else {
            return Diagnostic(
                lineIndex: block.headerIndex,
                kind: .dateDisagreement(suspect: .numericDate),
                reasoning: "\(header.month)/\(header.day)/\(header.year) is not a real date."
            )
        }
        guard let actualWeekday = header.actualWeekday, actualWeekday != header.weekday else {
            return nil
        }

        // Two encodings out-vote one. If the deltas corroborate the date that was written,
        // the weekday is the outlier; otherwise the date is.
        if evidence.deltasAgree(with: statedDate) == true {
            let corrected = DayHeader(weekday: actualWeekday, date: statedDate)
            return Diagnostic(
                lineIndex: block.headerIndex,
                kind: .dateDisagreement(suspect: .weekday),
                reasoning: "\(header.month)/\(header.day)/\(header.year) is a "
                    + "\(actualWeekday.displayName), and the delta agrees with that date, "
                    + "so the weekday is what is wrong.",
                fix: Fix(
                    range: block.headerIndex..<(block.headerIndex + 1),
                    replacement: [corrected.rendered],
                    summary: "Change the weekday to \(actualWeekday.displayName)"
                )
            )
        }

        guard let candidate = correctedDate(for: evidence, statedDate: statedDate) else {
            return Diagnostic(
                lineIndex: block.headerIndex,
                kind: .dateDisagreement(suspect: .numericDate),
                reasoning: "The header says \(header.weekday.displayName), but "
                    + "\(header.month)/\(header.day)/\(header.year) is a \(actualWeekday.displayName)."
            )
        }

        let corrected = DayHeader(weekday: header.weekday, date: candidate.date)
        return Diagnostic(
            lineIndex: block.headerIndex,
            kind: .dateDisagreement(suspect: .numericDate),
            reasoning: "\(header.month)/\(header.day)/\(header.year) is a "
                + "\(actualWeekday.displayName), not a \(header.weekday.displayName). \(candidate.evidence)",
            fix: Fix(
                range: block.headerIndex..<(block.headerIndex + 1),
                replacement: [corrected.rendered],
                summary: "Change the date to \(corrected.month)/\(corrected.day)/\(corrected.year)"
            )
        )
    }

    /// Looks for a date that carries the weekday as written.
    ///
    /// Delta-derived candidates come first: a gap that was lived is better evidence than a
    /// guess at which digit slipped. Only if no delta pins the block down does this fall back
    /// to the smallest edit that reconciles the weekday.
    private static func correctedDate(
        for evidence: HeaderEvidence,
        statedDate: Date
    ) -> (date: Date, evidence: String)? {
        let header = evidence.block.header

        if let gap = evidence.claimedGapToNewer, let newerDate = evidence.newerDate {
            let candidate = JournalCalendar.adding(days: -gap, to: newerDate)
            if JournalCalendar.weekday(of: candidate) == header.weekday {
                let parts = JournalCalendar.parts(of: candidate)
                return (candidate, "The weekday and the delta of \(gap) days both say "
                    + "\(parts.month)/\(parts.day)/\(parts.year).")
            }
        }
        if let gap = evidence.claimedGapToOlder, let olderDate = evidence.olderDate {
            let candidate = JournalCalendar.adding(days: gap, to: olderDate)
            if JournalCalendar.weekday(of: candidate) == header.weekday {
                let parts = JournalCalendar.parts(of: candidate)
                return (candidate, "The weekday and the delta of \(gap) days below both say "
                    + "\(parts.month)/\(parts.day)/\(parts.year).")
            }
        }

        // No delta to lean on. Prefer a wrong year over a wrong day: a stale year is the
        // classic January slip, and it is a smaller claim than moving the day.
        for offset in [1, -1, 2, -2] {
            guard let candidate = JournalCalendar.date(
                month: header.month, day: header.day, year: header.year + offset
            ) else { continue }
            if JournalCalendar.weekday(of: candidate) == header.weekday {
                return (candidate, "\(header.month)/\(header.day)/\(header.year + offset) is a "
                    + "\(header.weekday.displayName).")
            }
        }
        for offset in [1, -1, 2, -2, 3, -3] {
            let candidate = JournalCalendar.adding(days: offset, to: statedDate)
            if JournalCalendar.weekday(of: candidate) == header.weekday {
                let parts = JournalCalendar.parts(of: candidate)
                return (candidate, "The nearest \(header.weekday.displayName) is "
                    + "\(parts.month)/\(parts.day)/\(parts.year).")
            }
        }
        return nil
    }

    /// A delta that contradicts the gap between its two blocks.
    ///
    /// Only reported when both headers are internally consistent -- weekday matching numeric
    /// date on each side. If either header is already suspect, the gap is wrong *because* of
    /// that, and blaming the delta would be a second complaint about one mistake. That is not
    /// hypothetical: the corpus's `delta 2 days` above `saturday 2/28` is correct, and reads
    /// as wrong only because the block above it carries the bad date.
    private static func deltaDisagreements(
        _ document: Document, blocks: [Block]
    ) -> [Diagnostic] {
        blocks.indices.dropFirst().compactMap { index in
            let block = blocks[index]
            let newer = blocks[index - 1]
            guard let claimed = block.deltaAbove,
                  let deltaIndex = block.deltaAboveIndex,
                  let date = block.header.date,
                  let newerDate = newer.header.date,
                  block.header.weekdayMatchesDate,
                  newer.header.weekdayMatchesDate
            else { return nil }

            let actual = JournalCalendar.days(from: date, to: newerDate)
            guard actual != claimed else { return nil }

            let corrected = Grammar.deltaLine(days: actual)
            return Diagnostic(
                lineIndex: deltaIndex,
                kind: .deltaDisagreement,
                reasoning: "\(newer.header.displayRendered) and \(block.header.displayRendered) are "
                    + "\(actual) day\(actual == 1 ? "" : "s") apart, but this says \(claimed). "
                    + "Both headers agree with themselves, so the delta is what is wrong.",
                fix: Fix(
                    range: deltaIndex..<(deltaIndex + 1),
                    replacement: [corrected],
                    summary: "Change the delta to \(actual) day\(actual == 1 ? "" : "s")"
                )
            )
        }
    }

    // MARK: - Section order

    /// Roll writes open -> done -> next. Reading tolerates any order; this only points out
    /// where the file drifted from the convention.
    private static let conventionalOrder: [SectionLabel] = [.done, .next]

    private static func sectionOrderProblems(
        _ document: Document, blocks: [Block]
    ) -> [Diagnostic] {
        blocks.compactMap { block in
            let labelled = block.sections.filter { $0.label != nil }
            let labels = labelled.compactMap(\.label)
            guard labels.count > 1 else { return nil }
            guard labels != conventionalOrder.filter(labels.contains) else { return nil }

            return Diagnostic(
                lineIndex: block.headerIndex,
                kind: .sectionOrder,
                reasoning: "This block has "
                    + labels.map(\.displayName).joined(separator: " before ")
                    + ". The conventional order is open items, then Done, then Next.",
                fix: reorderFix(for: block, in: document)
            )
        }
    }

    private static func reorderFix(for block: Block, in document: Document) -> Fix? {
        let ordered = block.sections.sorted { left, right in
            rank(left.label) < rank(right.label)
        }
        guard let start = block.sections.compactMap(sectionStart).min(),
              let end = block.sections.compactMap(sectionEnd).max()
        else { return nil }

        // Only offer the reorder when the span holds nothing but these sections' own lines.
        // Anything else in there -- a stray blank, a line the grammar could not read -- would
        // be silently relocated, and moving text the app does not understand is exactly what
        // it must never do.
        let accounted = Set(block.sections.flatMap { section in
            section.itemIndices + [section.labelIndex].compactMap { $0 }
        })
        guard Set(start...end) == accounted else { return nil }

        let replacement = ordered.flatMap { section in
            ([section.labelIndex].compactMap { $0 } + section.itemIndices)
                .map { document.lines[$0].raw }
        }
        return Fix(
            range: start..<(end + 1),
            replacement: replacement,
            summary: "Reorder the sections to "
                + ordered.map { $0.label?.displayName ?? "Open" }.joined(separator: ", ")
        )
    }

    private static func sectionStart(_ section: Section) -> Int? {
        section.labelIndex ?? section.itemIndices.first
    }

    private static func sectionEnd(_ section: Section) -> Int? {
        section.itemIndices.last ?? section.labelIndex
    }

    private static func rank(_ label: SectionLabel?) -> Int {
        switch label {
        case .none: 0
        case .done: 1
        case .next: 2
        }
    }
}
