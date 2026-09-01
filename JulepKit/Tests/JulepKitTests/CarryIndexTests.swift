import Foundation
import Testing
@testable import JulepKit

@Suite("Carry counts")
struct CarryIndexTests {
    let index = CarryIndex(Document(Corpus.text))

    /// The case the feature exists for. This item was never done, and it was already running
    /// before the extract begins -- it survives by being copied forward one day at a time,
    /// because copying is cheaper than deciding.
    @Test func theUltrasoundRunIsFound() {
        let ultrasound = index.longestRuns().first
        #expect(ultrasound?.text.hasPrefix("book the annual checkup") == true)
        #expect(ultrasound?.streak == 35)
    }

    @Test func theRebateRunIsFound() {
        let run = index.longestRuns().first { $0.text == "chase down the rebate" }
        #expect(run?.streak == 7)
        #expect(run?.newestBlockIndex == 0)
    }

    /// An item that moved to `done` is resolved, which ends its run.
    @Test func resolvingAnItemEndsTheRun() {
        let document = Document("""
        wednesday 1/14/2026
        - a thing

        tuesday 1/13/2026
        done
        - a thing

        monday 1/12/2026
        - a thing
        """)
        let index = CarryIndex(document)
        #expect(index.streak(of: "a thing", from: 0) == 1)
        #expect(index.streak(of: "a thing", from: 1) == 0)
        #expect(index.streak(of: "a thing", from: 2) == 1)
    }

    /// `next` counts as unresolved -- it is still a decision waiting to be made.
    @Test func nextCountsAsCarried() {
        let document = Document("""
        wednesday 1/14/2026
        - a thing

        tuesday 1/13/2026
        next
        - a thing
        """)
        #expect(CarryIndex(document).streak(of: "a thing", from: 0) == 2)
    }

    @Test func anItemPresentOnceIsNotAStreak() {
        #expect(index.longestRuns(minimum: 2).allSatisfy { $0.streak >= 2 })
        #expect(index.streak(of: "no such item anywhere", from: 0) == 0)
    }

    /// Runs are reported from their newest block, so the same run is never counted twice.
    @Test func eachRunIsReportedOnce() {
        let texts = index.longestRuns().map(\.text)
        #expect(texts.count == Set(texts).count)
    }
}
