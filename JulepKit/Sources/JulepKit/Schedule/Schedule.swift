import Foundation

/// A deferral, read out of the journal rather than kept beside it.
///
/// There is no schedule file. Every `@schedule(...)` ever written is still in the journal --
/// roll only prepends, so the annotation stays on the line that recorded the decision -- and
/// that is enough to say what is deferred and when it comes back. A second file could only
/// ever agree or disagree with this one, and disagreeing was the whole risk.
public struct ScheduledItem: Equatable, Sendable {
    /// The item's text without its annotation, as it will be written back when it comes due.
    /// Text is the identity here as everywhere else -- no ids are stored.
    public var text: String
    public var kind: Kind

    public enum Kind: Equatable, Sendable {
        case oneShot(due: Date)
        /// The rule verbatim, and the day it was written. Occurrences count from there.
        ///
        /// Verbatim because resolving it to a date would throw away the thing that makes it
        /// a recurrence.
        case recurring(rule: String, start: Date)
    }

    public init(text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }

    public var rule: String? {
        if case .recurring(let rule, _) = kind { return rule }
        return nil
    }

    /// The first time this comes due after `after` and no later than `through`.
    ///
    /// A half-open window, which is what makes delivery answerable without tracking state:
    /// a roll covers the span from the previous block to today, and an item is delivered if
    /// an occurrence falls in it. Two rolls the same day leave an empty window, so nothing
    /// fires twice; a gap of months collapses to a single instance, because only the first
    /// occurrence in the window is returned. The accreting backlog the whole system exists
    /// to prevent cannot form.
    public func occurrence(after: Date, through: Date) -> Date? {
        switch kind {
        case .oneShot(let due):
            return due > after && due <= through ? due : nil
        case .recurring(let rule, let start):
            guard let parsed = RecurrenceRuleParser.rule(from: rule) else { return nil }
            for occurrence in parsed.recurrences(of: start) {
                if occurrence > through { return nil }
                if occurrence > after { return occurrence }
            }
            return nil
        }
    }

    /// The next day this will surface, for showing a list of what is coming.
    public func nextOccurrence(after date: Date) -> Date? {
        switch kind {
        case .oneShot(let due):
            return due
        case .recurring(let rule, let start):
            guard let parsed = RecurrenceRuleParser.rule(from: rule) else { return nil }
            return parsed.recurrences(of: start).first { $0 > date }
        }
    }
}

extension ScheduleAnnotation {
    /// The argument that ends a schedule instead of starting one.
    ///
    /// The same word the `done` section uses, deliberately: the file has a small vocabulary
    /// and reusing it beats inventing a synonym. Written into a block's `done` section, so it
    /// reads as what it is and is not carried forward as an outstanding item.
    public static let cancellation = "done"
}

extension Document {
    /// Every live deferral, most recent annotation per item text winning.
    ///
    /// Later intent supersedes earlier: re-annotating something already deferred reschedules
    /// it, and `@schedule(done)` ends it. Both fall out of the same rule, and neither
    /// requires editing what was already written -- history stays as it was recorded.
    public var schedules: [ScheduledItem] {
        var decided: Set<String> = []
        var live: [ScheduledItem] = []

        // Blocks are newest first. Within a block, the last line is the latest thing written
        // that day, so it is read bottom-up -- an item cancelled and re-deferred on one day
        // ends up deferred.
        for block in blocks {
            guard let blockDate = block.header.date else { continue }
            for lineIndex in block.range.reversed() {
                guard case .item(let item) = lines[lineIndex].kind,
                      let annotation = item.annotation
                else { continue }

                // Nothing but the annotation on the line: there is no item to defer, and a
                // nameless entry in the list would never mean anything again.
                let text = item.textWithoutAnnotation
                guard !text.isEmpty, !decided.contains(text) else { continue }

                let argument = annotation.argument.trimmingCharacters(in: .whitespaces)
                if argument.caseInsensitiveCompare(ScheduleAnnotation.cancellation) == .orderedSame {
                    decided.insert(text)
                    continue
                }
                // An argument the app cannot read is not an intent it can act on. It is left
                // undecided rather than treated as a cancellation, so a typo cannot silently
                // end a repeat -- the unreadable annotation is visible in the line itself.
                guard let parsed = NaturalDates.parse(argument) else { continue }

                decided.insert(text)
                switch parsed {
                case .date(let due):
                    live.append(ScheduledItem(text: text, kind: .oneShot(due: due)))
                case .recurrence(let rule):
                    live.append(
                        ScheduledItem(text: text, kind: .recurring(rule: rule, start: blockDate))
                    )
                }
            }
        }
        return live
    }

    /// The newest block's date -- the far edge of everything already recorded, and so the
    /// near edge of the window the next roll covers.
    public var newestBlockDate: Date? { blocks.first?.header.date }

    /// What a roll dated `today` should bring forward.
    public func schedulesDue(asOf today: Date) -> [ScheduledItem] {
        // With no blocks at all there is no window; anything already due comes forward.
        guard let since = newestBlockDate else {
            return schedules.filter { ($0.nextOccurrence(after: .distantPast) ?? .distantFuture) <= today }
        }
        return schedules.filter { $0.occurrence(after: since, through: today) != nil }
    }

    /// Everything deferred, with the day it will next surface. Soonest first.
    ///
    /// An item already due reports the day it came due rather than its next one, so the list
    /// shows what the next roll will actually put in front of you.
    public func upcomingSchedules(asOf today: Date) -> [(item: ScheduledItem, due: Date)] {
        let since = newestBlockDate ?? .distantPast
        return schedules
            .compactMap { item in
                let due = item.occurrence(after: since, through: today)
                    ?? item.nextOccurrence(after: today)
                return due.map { (item, $0) }
            }
            .sorted { $0.1 < $1.1 }
    }

    /// Ends the deferral of `text`, by recording that decision in the newest block.
    ///
    /// Written rather than deleted, because there is nothing to delete: the deferral is an
    /// annotation in a block that roll will never rewrite. Cancelling is a new entry that
    /// supersedes it, which is also what makes it visible in the record -- the journal shows
    /// that the repeat was stopped, and when.
    public func cancellingSchedule(of text: String) -> Document? {
        guard !text.isEmpty, blocks.first != nil else { return nil }
        let line = "\(Grammar.itemMarker)\(text) "
            + "\(ScheduleAnnotation.opening)\(ScheduleAnnotation.cancellation)"
            + ScheduleAnnotation.closing
        return insertingIntoNewestDoneSection(line)
    }
}
