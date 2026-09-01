import Foundation
import Testing
@testable import JulepKit

private func day(_ month: Int, _ d: Int, _ year: Int = 2026) -> Date {
    JournalCalendar.date(month: month, day: d, year: year)!
}

@Suite("Recurrence rules")
struct RecurrenceRuleTests {
    @Test("Rule text parses", arguments: [
        "every day", "every 2 days", "every week", "every 2 weeks",
        "every month", "every 3 months", "every year", "every tuesday",
    ])
    func rulesParse(_ text: String) {
        #expect(RecurrenceRuleParser.rule(from: text) != nil)
    }

    @Test("Nonsense does not become a rule", arguments: [
        "every", "every fortnight", "every 0 weeks", "tuesday", "in 3 weeks",
    ])
    func nonRulesDoNotParse(_ text: String) {
        #expect(RecurrenceRuleParser.rule(from: text) == nil)
    }

    @Test func aWeekdayRuleFiresOnThatWeekday() {
        guard let rule = RecurrenceRuleParser.rule(from: "every tuesday") else {
            Issue.record("did not parse"); return
        }
        let fires = Array(rule.recurrences(of: day(4, 21)).prefix(3))
        #expect(fires.allSatisfy { JournalCalendar.weekday(of: $0) == .tuesday })
    }
}

/// Reading the schedule out of the journal, which is the only place it is written down.
@Suite("Deriving the schedule")
struct DerivedScheduleTests {
    @Test func aDatedAnnotationBecomesAOneShot() {
        let document = Document("""
        monday 8/31/2026
        - renew passport @schedule(9/8/2026)
        """)
        #expect(document.schedules.count == 1)
        #expect(document.schedules.first?.text == "renew passport")
        #expect(document.schedules.first?.kind == .oneShot(due: day(9, 8)))
    }

    /// A repeat counts from the day it was written, which is the block it sits in -- there
    /// is nowhere else for a start date to come from, and nowhere else it needs to be.
    @Test func aRepeatStartsFromTheBlockItWasWrittenIn() {
        let document = Document("""
        monday 8/31/2026
        - a newer thing

        tuesday 4/21/2026
        - water the plants @schedule(every 2 weeks)
        """)
        #expect(document.schedules.first?.kind == .recurring(rule: "every 2 weeks", start: day(4, 21)))
    }

    /// An annotation with no item in front of it has nothing to defer. It appears the moment
    /// `@schedule(` is typed on a fresh line, and a nameless row is only confusing.
    @Test func anAnnotationWithNoItemTextIsIgnored() {
        let document = Document("""
        monday 8/31/2026
        - @schedule(9/1/2026)
        - renew passport @schedule(9/8/2026)
        """)
        #expect(document.schedules.map(\.text) == ["renew passport"])
    }

    @Test func anUnreadableArgumentIsNotASchedule() {
        let document = Document("""
        monday 8/31/2026
        - a thing @schedule(nxet tuseday)
        """)
        #expect(document.schedules.isEmpty)
    }

    // MARK: - Newest wins

    /// Later intent supersedes earlier, which is what makes rescheduling work at all -- and
    /// it works without touching the older line, so the record of both decisions survives.
    @Test func aNewerAnnotationSupersedesAnOlderOne() {
        let document = Document("""
        monday 8/31/2026
        - water the plants @schedule(every month)

        tuesday 4/21/2026
        - water the plants @schedule(every 2 weeks)
        """)
        #expect(document.schedules.count == 1)
        #expect(document.schedules.first?.rule == "every month")
    }

    @Test func aCancellationEndsTheSchedule() {
        let document = Document("""
        monday 8/31/2026
        done
        - water the plants @schedule(done)

        tuesday 4/21/2026
        - water the plants @schedule(every 2 weeks)
        """)
        #expect(document.schedules.isEmpty)
    }

    /// Order is what decides it, so a cancellation older than the schedule means nothing.
    @Test func anOlderCancellationDoesNotEndANewerSchedule() {
        let document = Document("""
        monday 8/31/2026
        - water the plants @schedule(every 2 weeks)

        tuesday 4/21/2026
        done
        - water the plants @schedule(done)
        """)
        #expect(document.schedules.first?.rule == "every 2 weeks")
    }

    /// Within one day the last line written is the latest intent, so a repeat stopped and
    /// restarted the same day ends up running.
    @Test func withinOneBlockTheLastLineWins() {
        let document = Document("""
        monday 8/31/2026
        - water the plants @schedule(every 2 weeks)
        done
        - water the plants @schedule(done)
        """)
        #expect(document.schedules.isEmpty)
    }

    /// A typo must not silently stop a repeat. The unreadable line is visible in the journal;
    /// treating it as a cancellation would not be.
    @Test func anUnreadableArgumentDoesNotCancelAnOlderSchedule() {
        let document = Document("""
        monday 8/31/2026
        - water the plants @schedule(evrey 2 weeks)

        tuesday 4/21/2026
        - water the plants @schedule(every 2 weeks)
        """)
        #expect(document.schedules.first?.rule == "every 2 weeks")
    }

    @Test func cancellingIsCaseAndSpaceInsensitive() {
        for argument in ["done", "DONE", " Done "] {
            let document = Document("""
            monday 8/31/2026
            done
            - a thing @schedule(\(argument))

            tuesday 4/21/2026
            - a thing @schedule(every week)
            """)
            #expect(document.schedules.isEmpty, "argument: \(argument)")
        }
    }
}

/// Delivery, decided by the window a roll covers rather than by remembering what was handed
/// over. See `ScheduledItem.occurrence(after:through:)`.
@Suite("What comes due")
struct ScheduleWindowTests {
    private func journal(_ header: String, _ annotation: String) -> Document {
        Document("""
        \(header)
        - a thing @schedule(\(annotation))
        """)
    }

    @Test func aOneShotFiresOnTheFirstRollPastItsDate() {
        let document = journal("tuesday 4/21/2026", "9/8/2026")
        #expect(document.schedulesDue(asOf: day(9, 7)).isEmpty)
        #expect(document.schedulesDue(asOf: day(9, 8)).map(\.text) == ["a thing"])
    }

    /// The window starts where the last block ends, so an occurrence already covered by an
    /// earlier roll cannot come round again.
    @Test func aOneShotDoesNotFireTwice() {
        let document = Document("""
        thursday 9/10/2026
        - a thing

        tuesday 4/21/2026
        - a thing @schedule(9/8/2026)
        """)
        #expect(document.schedulesDue(asOf: day(9, 11)).isEmpty)
    }

    @Test func aRepeatFiresWhenAnOccurrenceFallsInTheWindow() {
        let document = journal("tuesday 4/21/2026", "every 2 weeks")
        // 5/5 is the first occurrence after the start.
        #expect(document.schedulesDue(asOf: day(5, 4)).isEmpty)
        #expect(document.schedulesDue(asOf: day(5, 5)).count == 1)
    }

    /// The corpus has a 47-day gap. "every 2 weeks" fires four times across it, and
    /// surfacing all four is exactly the accreting backlog this system exists to prevent.
    @Test func aLongGapYieldsOneInstanceNotFour() {
        let rule = RecurrenceRuleParser.rule(from: "every 2 weeks")!
        let missed = Array(rule.recurrences(of: day(4, 21)).prefix { $0 <= day(6, 7) })
        #expect(missed.count == 4, "the gap really does span four occurrences")

        let document = journal("tuesday 4/21/2026", "every 2 weeks")
        #expect(document.schedulesDue(asOf: day(6, 7)).count == 1)
    }

    /// Two rolls the same day leave an empty window, so nothing is delivered twice.
    @Test func rollingTwiceInADayDeliversNothingTheSecondTime() {
        let document = Document("""
        tuesday 5/5/2026
        - a thing

        tuesday 4/21/2026
        - a thing @schedule(every 2 weeks)
        """)
        #expect(document.schedulesDue(asOf: day(5, 5)).isEmpty)
    }

    @Test func aCancelledRepeatStopsComingDue() {
        let document = Document("""
        monday 8/31/2026
        done
        - a thing @schedule(done)

        tuesday 4/21/2026
        - a thing @schedule(every 2 weeks)
        """)
        #expect(document.schedulesDue(asOf: day(9, 30)).isEmpty)
    }

    // MARK: - The list

    @Test func upcomingIsSoonestFirstAndShowsWhatIsDueNow() {
        let document = Document("""
        monday 8/31/2026
        - later @schedule(10/1/2026)
        - sooner @schedule(9/8/2026)
        """)
        let upcoming = document.upcomingSchedules(asOf: day(9, 1))
        #expect(upcoming.map(\.item.text) == ["sooner", "later"])
        #expect(upcoming.map(\.due) == [day(9, 8), day(10, 1)])
    }

    @Test func anOverdueItemReportsTheDayItCameDue() {
        let document = journal("tuesday 4/21/2026", "9/8/2026")
        #expect(document.upcomingSchedules(asOf: day(9, 20)).map(\.due) == [day(9, 8)])
    }
}

@Suite("Cancelling a schedule")
struct ScheduleCancellationTests {
    /// Written into `done`, not the open section: roll carries the other sections forward,
    /// so a cancellation placed anywhere else would follow the user around forever.
    @Test func theCancellationGoesIntoTheNewestDoneSection() {
        let document = Document("""
        monday 8/31/2026
        - something else

        tuesday 4/21/2026
        - water the plants @schedule(every 2 weeks)
        """)
        guard let updated = document.cancellingSchedule(of: "water the plants") else {
            Issue.record("no edit"); return
        }
        #expect(updated.serialized.hasPrefix("""
        monday 8/31/2026
        - something else
        done
        - water the plants @schedule(done)
        """))
        #expect(updated.schedules.isEmpty)
    }

    /// The older annotation is left exactly as written -- the journal shows that the repeat
    /// existed and that it was stopped, rather than pretending it never happened.
    @Test func historyIsNotRewritten() {
        let document = Document("""
        monday 8/31/2026
        - something else

        tuesday 4/21/2026
        - water the plants @schedule(every 2 weeks)
        """)
        let updated = document.cancellingSchedule(of: "water the plants")
        #expect(updated?.serialized.contains("- water the plants @schedule(every 2 weeks)") == true)
    }

    /// Whatever text the caller read out of the document is the text it cancels, so the two
    /// cannot disagree.
    @Test func aCancellationMatchesTheDerivedText() {
        let document = Document("""
        monday 8/31/2026
        - [work] call the landlord @schedule(every month)
        """)
        guard let text = document.schedules.first?.text,
              let updated = document.cancellingSchedule(of: text)
        else { Issue.record("no schedule"); return }
        #expect(updated.schedules.isEmpty)
    }

    @Test func thereIsNothingToCancelInAnEmptyJournal() {
        #expect(Document("").cancellingSchedule(of: "a thing") == nil)
        #expect(Document("- no blocks here").cancellingSchedule(of: "a thing") == nil)
    }
}
