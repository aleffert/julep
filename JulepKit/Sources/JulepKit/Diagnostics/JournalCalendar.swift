import Foundation

/// Date arithmetic for the journal.
///
/// Fixed to UTC and the Gregorian calendar: these are calendar dates written by hand, not
/// instants, and a local time zone would let a DST boundary change a day count.
enum JournalCalendar {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// `nil` for dates that do not exist, such as `2/30`. `DateComponents` would silently
    /// roll those forward, which would turn a typo into a plausible wrong answer.
    static func date(month: Int, day: Int, year: Int) -> Date? {
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return nil }
        let rounded = calendar.dateComponents([.year, .month, .day], from: date)
        guard rounded.year == year, rounded.month == month, rounded.day == day else { return nil }
        return date
    }

    static func weekday(of date: Date) -> Weekday? {
        Weekday(calendarValue: calendar.component(.weekday, from: date))
    }

    static func days(from earlier: Date, to later: Date) -> Int {
        calendar.dateComponents([.day], from: earlier, to: later).day ?? 0
    }

    static func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// The same, for the units a relative phrase can name. Optional where `adding(days:to:)`
    /// is not: a month or a year can land on a day that does not exist, and rolling that
    /// forward would turn a phrase the user typed into a date they did not mean.
    static func adding(_ value: Int, _ component: Calendar.Component, to date: Date) -> Date? {
        calendar.date(byAdding: component, value: value, to: date)
    }

    static func parts(of date: Date) -> (month: Int, day: Int, year: Int) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return (components.month ?? 0, components.day ?? 0, components.year ?? 0)
    }
}

extension DayHeader {
    /// The date this header names, or `nil` if it names no real date.
    public var date: Date? {
        JournalCalendar.date(month: month, day: day, year: year)
    }

    /// The weekday the numeric date actually falls on.
    public var actualWeekday: Weekday? {
        date.flatMap(JournalCalendar.weekday(of:))
    }

    public var weekdayMatchesDate: Bool {
        guard let actualWeekday else { return false }
        return actualWeekday == weekday
    }

    public init(weekday: Weekday, date: Date) {
        let parts = JournalCalendar.parts(of: date)
        self.init(weekday: weekday, month: parts.month, day: parts.day, year: parts.year)
    }

    /// Rendered the way the journal writes headers: lowercase weekday, unpadded `M/D/YYYY`.
    /// This is what gets written to the file.
    public var rendered: String {
        "\(weekday.rawValue) \(month)/\(day)/\(year)"
    }

    /// The same header for the app to talk about, with the weekday capitalised.
    public var displayRendered: String {
        "\(weekday.displayName) \(month)/\(day)/\(year)"
    }
}
