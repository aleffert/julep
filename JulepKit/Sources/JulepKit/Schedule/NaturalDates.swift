import Foundation

/// What a `@schedule(...)` argument turned out to mean.
public enum ScheduleArgument: Equatable, Sendable {
    /// A one-shot date, already resolved to a concrete day.
    case date(Date)
    /// A repeat, kept verbatim. Resolving it would throw away the very thing that makes it
    /// a recurrence.
    case recurrence(String)
}

/// Reads the natural-language argument of a `@schedule(...)` annotation.
///
/// Natural language is purely an input convenience. A one-shot date is resolved and written
/// back concrete immediately, so the file never stores anything ambiguous and still makes
/// sense read cold in six months. A misparse is then visible at the moment of typing rather
/// than surfacing at a roll weeks later.
public enum NaturalDates {
    public static let recurrenceKeyword = "every"

    // `NSDataDetector` inherits `NSRegularExpression`'s thread safety and is expensive to
    // build, so it is made once and only ever read.
    nonisolated(unsafe) private static let detector = try! NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    /// `nil` for an argument that means nothing -- an empty one, or text no date can be read
    /// from. The argument is required, so nothing is a failure rather than a default.
    public static func parse(_ argument: String) -> ScheduleArgument? {
        let trimmed = argument.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Recurrence is checked first, and this ordering is load-bearing. `NSDataDetector`
        // reads "every tuesday" as plain "tuesday" and hands back next Tuesday's date, which
        // would quietly turn a repeat into a one-shot.
        if isRecurrence(trimmed) { return .recurrence(trimmed) }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = detector.matches(in: trimmed, options: [], range: range).first,
              let date = match.date,
              let day = normalizedDay(date)
        else { return nil }
        return .date(day)
    }

    /// The day a `Date` falls on, as a calendar day.
    ///
    /// `NSDataDetector` resolves against the *local* calendar and hands back noon local time,
    /// while everything here is a calendar day at UTC midnight. Left unconverted, a user east
    /// of UTC would have noon local land on the previous UTC day and see the wrong date
    /// written into their file. So the local Y/M/D is read out first, then reinterpreted as a
    /// journal day.
    static func normalizedDay(_ date: Date, in zone: Calendar = .autoupdatingCurrent) -> Date? {
        let parts = zone.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day
        else { return nil }
        return JournalCalendar.date(month: month, day: day, year: year)
    }

    /// A journal day some number of days from another. Exposed so callers can offer relative
    /// deferrals without reaching into the calendar themselves.
    public static func day(_ days: Int, after date: Date = today()) -> Date {
        JournalCalendar.adding(days: days, to: date)
    }

    /// Today as a journal day, normalized the same way parsed dates are. Comparing a parsed
    /// date against anything else risks an off-by-one across the UTC boundary.
    public static func today(now: Date = Date()) -> Date {
        normalizedDay(now) ?? now
    }

    public static func isRecurrence(_ argument: String) -> Bool {
        let trimmed = argument.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed == recurrenceKeyword || trimmed.hasPrefix(recurrenceKeyword + " ")
    }

    /// `M/D/YYYY`, unpadded -- the way the journal writes dates everywhere else.
    public static func canonical(_ date: Date) -> String {
        let parts = JournalCalendar.parts(of: date)
        return "\(parts.month)/\(parts.day)/\(parts.year)"
    }

    /// What should be written back into the file for this argument.
    public static func canonicalText(for argument: ScheduleArgument) -> String {
        switch argument {
        case .date(let date): canonical(date)
        case .recurrence(let text): text
        }
    }

    /// Rewrites a `@schedule(...)` argument to its canonical form, which is what happens on
    /// entry. Returns `nil` if the argument could not be read, so the caller can flag it
    /// instead of writing something wrong.
    public static func canonicalizing(_ argument: String) -> String? {
        parse(argument).map(canonicalText(for:))
    }
}
