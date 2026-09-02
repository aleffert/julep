import Foundation
import Testing
@testable import JulepKit

private func day(_ month: Int, _ d: Int, _ year: Int = 2026) -> Date {
    JournalCalendar.date(month: month, day: d, year: year)!
}

@Suite("Roll planning")
struct RollPlanTests {
    let document = Document(Corpus.text)

    /// The corpus head is sunday 8/30/2026; rolling on 9/2 is three days later.
    func plan(on today: Date) -> RollPlan? {
        Roll.plan(document: document, today: today)
    }

    @Test func theHeaderAndDeltaAreComputedNotTyped() {
        guard let plan = plan(on: day(9, 2)) else { Issue.record("no plan"); return }
        #expect(plan.header.rendered == "wednesday 9/2/2026")
        #expect(plan.delta == 3)
    }

    /// Candidates come from open and next, never from done.
    @Test func candidatesComeFromTheUnresolvedSections() {
        guard let plan = plan(on: day(9, 2)) else { Issue.record("no plan"); return }
        #expect(plan.candidates.map(\.text) == ["chase down the rebate", "harass landlord"])
        #expect(plan.candidates.map(\.section) == [nil, .next])
    }

    /// The carry count is still computed -- `carry-nudge` is deferred, not deleted, and the
    /// detection is what a future home for it would read.
    @Test func carryCountsAreStillAvailable() {
        guard let plan = plan(on: day(9, 2)) else { Issue.record("no plan"); return }
        guard let stale = plan.candidates.first(where: { $0.text == "chase down the rebate" }) else {
            Issue.record("missing"); return
        }
        #expect(stale.carryStreak == 7)
        #expect(stale.suggestsSchedule)

        guard let fresh = plan.candidates.first(where: { $0.text == "harass landlord" }) else {
            Issue.record("missing"); return
        }
        #expect(fresh.carryStreak == 1)
        #expect(!fresh.suggestsSchedule)
    }

    @Test func dueDeferralsAreInjected() {
        let document = Document("""
        sunday 8/30/2026
        - renew passport @schedule(9/1/2026)
        - not yet @schedule(12/1/2026)
        """)
        guard let plan = Roll.plan(document: document, today: day(9, 2))
        else { Issue.record("no plan"); return }
        #expect(plan.injections.map(\.text) == ["renew passport"])
    }

    /// An annotated item has already been decided about, so it is neither carried nor
    /// offered for triage again -- the annotation on its line says what happens to it.
    @Test func annotatedItemsAreNotOfferedForTriage() {
        let document = Document("""
        sunday 8/30/2026
        - chase down the rebate @schedule(9/8/2026)
        - still undecided
        """)
        guard let plan = Roll.plan(document: document, today: day(9, 2))
        else { Issue.record("no plan"); return }

        #expect(plan.candidates.map(\.text) == ["still undecided"])
        #expect(document.schedules.map(\.text) == ["chase down the rebate"])
    }
}

@Suite("Rolling")
struct RollApplyTests {
    /// One action: everything unresolved comes forward as a todo, no prompts.
    @Test func rollCarriesEverythingForwardInOneStep() {
        let document = Document("""
        sunday 8/30/2026
        - chase down the rebate
        done
        - already finished
        next
        - harass landlord
        """)
        guard let rolled = Roll.roll(document: document, today: day(9, 2)
        ) else { Issue.record("no roll"); return }

        let lines = rolled.serialized.components(separatedBy: "\n")
        #expect(lines[0] == "wednesday 9/2/2026")
        #expect(lines[1] == "- chase down the rebate")
        // What was queued under `next` was queued for today, so today it is a todo.
        #expect(lines[2] == "- harass landlord")
        #expect(rolled.blocks[0].section(.next) == nil)
        // Finished items stay behind; only what is unresolved comes forward.
        #expect(!lines[0...2].contains("- already finished"))
    }

    let document = Document(Corpus.text)

    @Test func theNewBlockIsWrittenWithADerivedHeaderAndDelta() {
        guard let plan = Roll.plan(document: document, today: day(9, 2))
        else { Issue.record("no plan"); return }

        let rolled = Roll.apply(plan, decisions: [:], to: document)
        let lines = rolled.serialized.components(separatedBy: "\n")

        #expect(lines[0] == "wednesday 9/2/2026")
        #expect(lines[1] == "- chase down the rebate")
        #expect(lines[2] == "- harass landlord")
        #expect(lines[3] == "")
        #expect(lines[4] == "delta 3 days")
        #expect(lines[5] == "")
        #expect(lines[6] == "sunday 8/30/2026")
    }

    /// A one-day gap is what most days are, and the header already says which day it is.
    /// Writing `delta 1 day` above nearly every block would bury the deltas that mean
    /// something -- the ones marking a gap that was actually skipped.
    @Test func aOneDayGapIsNotWrittenAsADelta() {
        // The corpus head is sunday 8/30/2026, so rolling on the 31st is one day on.
        guard let plan = Roll.plan(document: document, today: day(8, 31))
        else { Issue.record("no plan"); return }
        // Still reported: the gap is a fact about the journal, and only the line is dropped.
        #expect(plan.delta == 1)

        let rolled = Roll.apply(plan, decisions: [:], to: document)
        let lines = rolled.serialized.components(separatedBy: "\n")
        #expect(lines[0] == "monday 8/31/2026")
        #expect(!lines.contains("delta 1 day"))
        // One blank line between the new block and the one it was rolled from, where the
        // delta would otherwise have sat.
        let header = lines.firstIndex(of: "sunday 8/30/2026")
        #expect(header != nil)
        if let header { #expect(lines[header - 1] == "") }
    }

    /// The block below still finds no delta above it, rather than finding a stray one.
    @Test func aSkippedOneDayDeltaLeavesTheBlockStructureIntact() {
        guard let plan = Roll.plan(document: document, today: day(8, 31))
        else { Issue.record("no plan"); return }
        let rolled = Roll.apply(plan, decisions: [:], to: document)
        let blocks = rolled.blocks
        #expect(blocks[0].header.rendered == "monday 8/31/2026")
        #expect(blocks[1].deltaAbove == nil)
        // And nothing the grammar cannot read was left behind.
        #expect(Diagnostics.analyze(rolled).allSatisfy { $0.kind != .unrecognizedLine })
    }

    /// Roll only prepends. Everything already written stays exactly as it was.
    @Test func historyIsNeverRewritten() {
        guard let plan = Roll.plan(document: document, today: day(9, 2))
        else { Issue.record("no plan"); return }
        let rolled = Roll.apply(plan, decisions: [:], to: document)
        #expect(rolled.serialized.hasSuffix(Corpus.text))
    }

    @Test func eachDecisionSendsTheItemWhereItBelongs() {
        let document = Document("""
        sunday 8/30/2026
        - carried
        - finished
        - deferred
        - abandoned
        """)
        guard let plan = Roll.plan(document: document, today: day(9, 2))
        else { Issue.record("no plan"); return }

        let rolled = Roll.apply(
            plan,
            decisions: [
                "carried": .carry,
                "finished": .done,
                "deferred": .schedule("every 2 weeks"),
                "abandoned": .drop,
            ],
            to: document
        )
        // A deferral joins the open section, which is exactly where a hand-typed annotation
        // would sit: it is a line recording today's decision, and its annotation keeps it
        // from being carried any further.
        let lines = rolled.serialized.components(separatedBy: "\n")
        #expect(lines[0] == "wednesday 9/2/2026")
        #expect(lines[1] == "- carried")
        #expect(lines[2] == "- deferred @schedule(every 2 weeks)")
        #expect(lines[3] == "done")
        #expect(lines[4] == "- finished")
        #expect(!rolled.serialized.contains("- abandoned\nwednesday"))

        // The deferred item is written into today's block carrying its annotation, which is
        // where the deferral is read back from -- there is nowhere else for it to live.
        #expect(rolled.serialized.contains("- deferred @schedule(every 2 weeks)"))
        #expect(rolled.schedules.map(\.text) == ["deferred"])
        #expect(rolled.schedules[0].rule == "every 2 weeks")
    }

    @Test func anAnnotatedLineStaysWhereItWasWrittenAndIsNotCarried() {
        let document = Document("""
        sunday 8/30/2026
        - chase down the rebate @schedule(9/8/2026)
        """)
        guard let plan = Roll.plan(document: document, today: day(9, 2))
        else { Issue.record("no plan"); return }
        let rolled = Roll.apply(plan, decisions: [:], to: document)

        // The annotated line is still there, in the block it was written in.
        #expect(rolled.serialized.contains("- chase down the rebate @schedule(9/8/2026)"))
        // And it was not carried into the new block.
        #expect(rolled.blocks[0].openSection == nil)
        // The deferral is still readable, because that line is what it is read from.
        #expect(rolled.schedules.map(\.text) == ["chase down the rebate"])
    }

    /// Delivered once, and only once. Nothing records that it happened -- the new block's
    /// date moves the next roll's window past the occurrence, which is enough.
    @Test func injectedItemsEnterTheNewBlockAndDoNotComeBack() {
        let document = Document("""
        sunday 8/30/2026
        - renew passport @schedule(9/1/2026)
        """)
        guard let plan = Roll.plan(document: document, today: day(9, 2))
        else { Issue.record("no plan"); return }

        let rolled = Roll.apply(plan, decisions: [:], to: document)
        #expect(rolled.serialized.components(separatedBy: "\n")[1] == "- renew passport")
        #expect(rolled.schedulesDue(asOf: day(9, 3)).isEmpty, "a spent one-shot does not return")
    }

    /// Nothing is carried without a decision having been made about it.
    @Test func rollingAnEmptyJournalProducesJustAHeader() {
        let empty = Document("")
        guard let plan = Roll.plan(document: empty, today: day(9, 2))
        else { Issue.record("no plan"); return }
        #expect(plan.candidates.isEmpty)
        #expect(plan.delta == nil)

        let rolled = Roll.apply(plan, decisions: [:], to: empty)
        #expect(rolled.serialized.hasPrefix("wednesday 9/2/2026"))
        #expect(!rolled.serialized.contains("delta"))
    }
}
