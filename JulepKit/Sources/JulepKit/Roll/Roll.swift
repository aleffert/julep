import Foundation

/// What the user decided about one item during triage.
public enum TriageDecision: Equatable, Sendable {
    /// Copy it forward, keeping the section it was in.
    case carry
    /// It actually got done.
    case done
    /// Push it out to a date or a repeat, with this `@schedule` argument.
    case schedule(String)
    /// It is not going to happen.
    case drop
}

/// One item awaiting a decision.
public struct TriageCandidate: Equatable, Sendable {
    public var text: String
    /// The section it came from. `nil` is the unlabeled open section.
    public var section: SectionLabel?
    /// Consecutive blocks this has been carried unresolved, including the one it is in.
    public var carryStreak: Int
    /// Whether the streak is long enough to suggest `@schedule` instead of another carry.
    public var suggestsSchedule: Bool
}

/// Everything roll wants to show, computed but not yet acted on.
public struct RollPlan: Equatable, Sendable {
    public var header: DayHeader
    /// Days since the previous block. `nil` when there is no previous block.
    public var delta: Int?
    /// Items to walk through one at a time. Every one gets touched and judged.
    public var candidates: [TriageCandidate]
    /// Deferred items that have come due, entering the new block's open section.
    ///
    /// Read out of the journal's own annotations rather than a store beside it, so there is
    /// nothing to keep in step. See `Document.schedulesDue(asOf:)`.
    public var injections: [ScheduledItem]
}

/// Builds and applies a roll.
///
/// One action: every open and `next` item comes forward, each into the section it came from,
/// and pruning happens afterwards in the editor. An earlier version walked the items asking
/// about each one; that turned out to be a form to fill in rather than a decision gate.
public enum Roll {
    /// How many consecutive carries before an item is flagged as a `@schedule` candidate.
    public static let defaultNudgeThreshold = 4

    public static func plan(
        document: Document,
        today: Date,
        nudgeThreshold: Int = defaultNudgeThreshold
    ) -> RollPlan? {
        guard let weekday = JournalCalendar.weekday(of: today) else { return nil }
        let header = DayHeader(weekday: weekday, date: today)
        let blocks = document.blocks
        let index = CarryIndex(document)

        guard let head = blocks.first else {
            return RollPlan(
                header: header, delta: nil, candidates: [],
                injections: document.schedulesDue(asOf: today)
            )
        }

        var candidates: [TriageCandidate] = []

        for section in head.sections where section.label != .done {
            for lineIndex in section.itemIndices {
                guard case .item(let item) = document.lines[lineIndex].kind else { continue }

                // An annotated item has already been decided about, and the annotation says
                // so where it was written. It is not carried and not offered for triage
                // again; the deferral is read straight back out of that line.
                guard item.annotation == nil else { continue }

                let streak = index.streak(of: item.text, from: 0)
                candidates.append(TriageCandidate(
                    text: item.text,
                    section: section.label,
                    carryStreak: streak,
                    suggestsSchedule: streak >= nudgeThreshold
                ))
            }
        }

        return RollPlan(
            header: header,
            delta: head.header.date.map { JournalCalendar.days(from: $0, to: today) },
            candidates: candidates,
            injections: document.schedulesDue(asOf: today)
        )
    }

    /// Rolls in one step: carries everything forward, injects what is due, files what was
    /// annotated. The common path, and the only one the UI uses.
    public static func roll(document: Document, today: Date) -> Document? {
        guard let plan = plan(document: document, today: today) else { return nil }
        return apply(plan, decisions: [:], to: document)
    }

    /// Writes the new block.
    ///
    /// Only ever prepends: earlier blocks are never rewritten, so the record of what was
    /// decided on a given day stays exactly as it was written.
    ///
    /// `decisions` defaults to carrying everything. It remains a parameter because
    /// `@schedule` annotations and due injections still route through here, and because the
    /// per-item outcomes are worth keeping testable.
    public static func apply(
        _ plan: RollPlan,
        decisions: [String: TriageDecision],
        to document: Document
    ) -> Document {
        var open: [String] = []
        var done: [String] = []
        var next: [String] = []

        // Due items enter the new day's open section. Nothing records that they were
        // delivered: the block they land in is dated, and the next roll's window starts
        // where this one ends, so the same occurrence cannot come round twice.
        for injection in plan.injections {
            open.append(injection.text)
        }

        for candidate in plan.candidates {
            switch decisions[candidate.text] ?? .carry {
            case .carry:
                switch candidate.section {
                case .next: next.append(candidate.text)
                case .done, .none: open.append(candidate.text)
                }
            case .done:
                // Recorded against today rather than backdated -- roll never edits history.
                done.append(candidate.text)
            case .drop:
                break
            case .schedule(let argument):
                // Written into today's block with its annotation intact, which is what makes
                // it a deferral: the line records the decision and is where it is read back
                // from. An annotated item is not carried, so it stays in this day's record.
                guard NaturalDates.parse(argument) != nil else { break }
                open.append(
                    "\(candidate.text) \(ScheduleAnnotation.opening)\(argument)"
                        + ScheduleAnnotation.closing
                )
            }
        }

        var lines = [plan.header.rendered]
        lines += open.map { "- \($0)" }
        if !done.isEmpty { lines += ["done"] + done.map { "- \($0)" } }
        if !next.isEmpty { lines += ["next"] + next.map { "- \($0)" } }
        lines.append("")
        // A one-day gap is the ordinary case and the header already says so -- writing
        // `delta 1 day` above every block would be noise on all but the days that skipped.
        // `plan.delta` still reports it; only the line is left out.
        if let delta = plan.delta, delta != 1 {
            lines += [Grammar.deltaLine(days: delta), ""]
        }

        let prepended = lines.map { Line(raw: $0, kind: Grammar.classify($0)) }
        return Document(lines: prepended + document.lines)
    }
}
