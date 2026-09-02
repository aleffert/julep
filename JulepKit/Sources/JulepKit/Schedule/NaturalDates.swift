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

    // `NSDataDetector` is `Sendable`, inheriting `NSRegularExpression`'s thread safety,
    // and is expensive to build -- so it is made once and only ever read.
    private static let detector = try! NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    )

    /// `nil` for an argument that means nothing -- an empty one, or text no date can be read
    /// from. The argument is required, so nothing is a failure rather than a default.
    ///
    /// `reference` is the day the argument is read from, and is the block the annotation
    /// sits under wherever one is in hand. An annotation means what it meant on the day it
    /// was written; `today` is only the fallback for callers with no block to offer.
    public static func parse(
        _ argument: String, relativeTo reference: Date = today()
    ) -> ScheduleArgument? {
        let trimmed = argument.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Recurrence is checked first, and this ordering is load-bearing. `NSDataDetector`
        // reads "every tuesday" as plain "tuesday" and hands back next Tuesday's date, which
        // would quietly turn a repeat into a one-shot.
        if isRecurrence(trimmed) { return .recurrence(trimmed) }

        // Then anything relative, for the same reason and one of its own: the detector
        // resolves "tomorrow" against the wall clock and takes no reference date at all, so
        // an argument typed into an older block would come out meaning tomorrow-from-now
        // rather than the day after the block it was written in.
        if let day = relative(trimmed, to: reference) { return .date(day) }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = detector.matches(in: trimmed, options: [], range: range).first,
              let date = match.date,
              let day = normalizedDay(date)
        else { return nil }
        return .date(day)
    }

    /// The number words worth reading, which is as far as a hand-typed deferral goes.
    /// Anything longer is a date, and a date is what the detector is for.
    private static let numberWords: [String: Int] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
    ]

    /// A phrase whose meaning is entirely relative, resolved against `reference`.
    ///
    /// Deliberately a small vocabulary rather than a parser. These are the phrases that mean
    /// something different depending on the day they are read from, and they are the only
    /// ones that have to be taken off the detector -- an absolute date means the same thing
    /// whenever it is read, so the detector can go on handling every form of one.
    private static func relative(_ text: String, to reference: Date) -> Date? {
        let words = text.lowercased().split(separator: " ").map(String.init)
        switch words.count {
        case 1:
            return day(named: words[0], from: reference)
        case 2 where words[0] == "next":
            // `next tuesday` and a bare `tuesday` are the same request; only `next week` and
            // its siblings are counted off in units.
            if let named = day(named: words[1], from: reference) { return named }
            return adding(1, words[1], to: reference)
        case 3 where words[0] == "in":
            guard let count = Int(words[1]) ?? numberWords[words[1]], count > 0 else {
                return nil
            }
            return adding(count, words[2], to: reference)
        default:
            return nil
        }
    }

    /// A day named outright: `today`, `tomorrow`, or a weekday.
    private static func day(named word: String, from reference: Date) -> Date? {
        switch word {
        case "today": return reference
        case "tomorrow": return day(1, after: reference)
        default:
            guard let weekday = Weekday(rawValue: word),
                  let current = JournalCalendar.weekday(of: reference)
            else { return nil }
            // Strictly after: naming the weekday you are already on means the next one, not
            // the day you are standing on. Nothing is ever deferred to itself.
            let ahead = (weekday.calendarValue - current.calendarValue + 7) % 7
            return day(ahead == 0 ? 7 : ahead, after: reference)
        }
    }

    private static func adding(_ count: Int, _ unit: String, to date: Date) -> Date? {
        switch unit {
        case "day", "days": JournalCalendar.adding(days: count, to: date)
        case "week", "weeks": JournalCalendar.adding(days: 7 * count, to: date)
        case "month", "months": JournalCalendar.adding(count, .month, to: date)
        case "year", "years": JournalCalendar.adding(count, .year, to: date)
        default: nil
        }
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
    public static func canonicalizing(
        _ argument: String, relativeTo reference: Date = today()
    ) -> String? {
        parse(argument, relativeTo: reference).map(canonicalText(for:))
    }
}
