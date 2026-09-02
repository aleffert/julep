import Foundation
import Testing
@testable import JulepKit

@Suite("Natural dates")
struct NaturalDatesTests {
    /// Normalized the same way parsed dates are, so the comparison cannot slip a day
    /// across the UTC boundary. The tests that pass no reference assert properties of the
    /// answer rather than a fixed value, because their answer moves with the wall clock.
    private var today: Date { NaturalDates.today() }

    /// A Tuesday, so a weekday argument can be checked in both directions from it.
    private var reference: Date {
        JournalCalendar.date(month: 4, day: 21, year: 2026)!
    }

    /// The reason the reference exists: an annotation means what it meant on the day it was
    /// written, and that day is the block it sits under -- not whenever it is read back.
    @Test("Relative arguments are read from the reference day", arguments: [
        ("today", "4/21/2026"),
        ("tomorrow", "4/22/2026"),
        ("in 3 days", "4/24/2026"),
        ("in a week", "4/28/2026"),
        ("next week", "4/28/2026"),
        ("in two weeks", "5/5/2026"),
        ("next month", "5/21/2026"),
        ("next year", "4/21/2027"),
        // Nothing is deferred to the day it was written, so naming the reference's own
        // weekday means the next one rather than standing still.
        ("wednesday", "4/22/2026"),
        ("next wednesday", "4/22/2026"),
        ("tuesday", "4/28/2026"),
    ])
    func relativeArgumentsUseTheReference(_ input: (argument: String, expected: String)) {
        guard case .date(let date)? = NaturalDates.parse(input.argument, relativeTo: reference)
        else {
            Issue.record("\(input.argument) did not resolve"); return
        }
        #expect(NaturalDates.canonical(date) == input.expected)
    }

    /// An absolute date means the same thing whenever it is read, so the reference must not
    /// reach it. This is what keeps the relative vocabulary from swallowing the detector's
    /// job rather than sitting in front of it.
    @Test("Absolute dates ignore the reference", arguments: ["9/8/2026", "December 1, 2026"])
    func absoluteDatesIgnoreTheReference(_ argument: String) {
        #expect(
            NaturalDates.canonicalizing(argument, relativeTo: reference)
                == NaturalDates.canonicalizing(argument)
        )
    }

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
