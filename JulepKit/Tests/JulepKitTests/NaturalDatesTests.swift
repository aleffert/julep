import Foundation
import Testing
@testable import JulepKit

@Suite("Natural dates")
struct NaturalDatesTests {
    /// `NSDataDetector` resolves relative to now and offers no way to inject a reference
    /// date, so these assert properties of the answer rather than a fixed value.
    /// Normalized the same way parsed dates are, so the comparison cannot slip a day
    /// across the UTC boundary.
    private var today: Date { NaturalDates.today() }

    @Test("One-shot arguments resolve to a concrete future date",
          arguments: ["tuesday", "tomorrow", "in 3 weeks", "next tuesday", "in 3 days"])
    func oneShotResolves(_ argument: String) {
        guard case .date(let date)? = NaturalDates.parse(argument) else {
            Issue.record("\(argument) did not resolve"); return
        }
        #expect(date > today)
        // And the written form is unambiguous when read cold.
        #expect(NaturalDates.canonical(date).wholeMatch(of: #/\d{1,2}/\d{1,2}/\d{4}/#) != nil)
    }

    @Test func aWeekdayResolvesToThatWeekdayWithinTheWeek() {
        guard case .date(let date)? = NaturalDates.parse("tuesday") else {
            Issue.record("did not resolve"); return
        }
        #expect(JournalCalendar.weekday(of: date) == .tuesday)
        #expect(JournalCalendar.days(from: today, to: date) <= 7)
    }

    /// The trap: `NSDataDetector` reads "every tuesday" as "tuesday" and returns a date.
    /// Checking for a recurrence first is what stops a repeat becoming a one-shot.
    @Test("Repeats stay repeats and are never resolved",
          arguments: ["every tuesday", "every 2 weeks", "every day", "EVERY MONDAY"])
    func recurrenceIsNotResolved(_ argument: String) {
        guard case .recurrence(let text)? = NaturalDates.parse(argument) else {
            Issue.record("\(argument) was not treated as a recurrence"); return
        }
        #expect(text == argument.trimmingCharacters(in: .whitespaces))
        #expect(NaturalDates.canonicalText(for: .recurrence(text)) == text)
    }

    /// "everything else" starts with "every" as a substring but is not a repeat.
    @Test func onlyTheWholeKeywordCountsAsARepeat() {
        #expect(!NaturalDates.isRecurrence("everything else"))
        #expect(NaturalDates.isRecurrence("every tuesday"))
    }

    @Test func anAlreadyConcreteDatePassesThrough() {
        guard case .date(let date)? = NaturalDates.parse("9/8/2026") else {
            Issue.record("did not resolve"); return
        }
        #expect(NaturalDates.canonical(date) == "9/8/2026")
        #expect(NaturalDates.canonicalizing("9/8/2026") == "9/8/2026")
    }

    /// The argument is required, so nothing readable is a failure rather than a default.
    @Test("Unreadable arguments fail rather than guessing",
          arguments: ["", "   ", "sometime", "the 15th"])
    func unreadableArgumentsReturnNil(_ argument: String) {
        #expect(NaturalDates.parse(argument) == nil)
        #expect(NaturalDates.canonicalizing(argument) == nil)
    }

    /// Regression: `NSDataDetector` hands back noon *local* time. Read as a UTC instant,
    /// that falls on the previous day for anyone far enough east, and the wrong date would be
    /// written into the file.
    @Test func aDateIsReadAsTheLocalDayNotTheUTCInstant() {
        var farEast = Calendar(identifier: .gregorian)
        farEast.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!  // UTC+14 year round
        let noonLocal = farEast.date(
            from: DateComponents(year: 2026, month: 9, day: 8, hour: 12)
        )!

        // The instant really does land on the previous day in UTC.
        #expect(NaturalDates.canonical(noonLocal) == "9/7/2026")
        // Normalizing recovers the day the user meant.
        guard let normalized = NaturalDates.normalizedDay(noonLocal, in: farEast) else {
            Issue.record("did not normalize"); return
        }
        #expect(NaturalDates.canonical(normalized) == "9/8/2026")
    }

    @Test func canonicalFormIsUnpadded() {
        guard let date = JournalCalendar.date(month: 9, day: 8, year: 2026) else {
            Issue.record("bad fixture"); return
        }
        #expect(NaturalDates.canonical(date) == "9/8/2026")
    }
}
