import Foundation
import Testing
@testable import JulepKit

private func lines(_ values: String...) -> String { values.joined(separator: "\n") }

@Suite("Text merge")
struct TextMergeTests {
    // MARK: - The trivial answers

    @Test func aSideThatDidNotMoveContributesNothing() {
        let base = lines("a", "b", "c")
        #expect(TextMerge.merge(base: base, mine: base, theirs: lines("a", "x", "c")) == .merged(lines("a", "x", "c")))
        #expect(TextMerge.merge(base: base, mine: lines("a", "x", "c"), theirs: base) == .merged(lines("a", "x", "c")))
    }

    /// The same change arriving from both sides is agreement. A roll seen twice is the
    /// ordinary way this happens.
    @Test func identicalChangesAreNotAConflict() {
        let both = lines("new", "a", "b")
        #expect(TextMerge.merge(base: lines("a", "b"), mine: both, theirs: both) == .merged(both))
    }

    // MARK: - The case this exists for

    /// A widget roll prepends a block while the app edits an item further down. The two never
    /// touch the same line, and neither side should have to be chosen over the other.
    @Test func aPrependedBlockMergesWithAnEditBelowIt() {
        let base = lines("sunday 8/30/2026", "- chase down the rebate", "", "saturday 8/29/2026", "- older")
        let rolled = lines(
            "monday 8/31/2026", "- chase down the rebate", "",
            "sunday 8/30/2026", "- chase down the rebate", "", "saturday 8/29/2026", "- older"
        )
        let edited = lines("sunday 8/30/2026", "- chase down the rebate today", "", "saturday 8/29/2026", "- older")

        let merged = TextMerge.merge(base: base, mine: edited, theirs: rolled)
        #expect(merged == .merged(lines(
            "monday 8/31/2026", "- chase down the rebate", "",
            "sunday 8/30/2026", "- chase down the rebate today", "", "saturday 8/29/2026", "- older"
        )))
    }

    @Test func editsToDifferentRegionsBothSurvive() {
        let base = lines("a", "b", "c", "d", "e")
        let mine = lines("a", "B", "c", "d", "e")
        let theirs = lines("a", "b", "c", "D", "e")
        #expect(TextMerge.merge(base: base, mine: mine, theirs: theirs) == .merged(lines("a", "B", "c", "D", "e")))
    }

    @Test func insertionsInDifferentPlacesBothSurvive() {
        let base = lines("a", "b", "c")
        let mine = lines("a", "inserted", "b", "c")
        let theirs = lines("a", "b", "c", "appended")
        #expect(TextMerge.merge(base: base, mine: mine, theirs: theirs)
            == .merged(lines("a", "inserted", "b", "c", "appended")))
    }

    @Test func aDeletionOnOneSideSurvivesAnEditOnTheOther() {
        let base = lines("a", "b", "c", "d")
        let mine = lines("a", "c", "d")
        let theirs = lines("a", "b", "c", "D")
        #expect(TextMerge.merge(base: base, mine: mine, theirs: theirs) == .merged(lines("a", "c", "D")))
    }

    // MARK: - What it refuses

    @Test func bothSidesChangingTheSameLineConflicts() {
        let base = lines("a", "b", "c")
        #expect(TextMerge.merge(base: base, mine: lines("a", "B", "c"), theirs: lines("a", "beta", "c"))
            == .conflicted)
    }

    @Test func anEditInsideTheOtherSidesReplacedRangeConflicts() {
        let base = lines("a", "b", "c", "d", "e")
        // Mine replaces b..d wholesale; theirs edits c, which is inside it.
        #expect(TextMerge.merge(base: base, mine: lines("a", "one", "e"), theirs: lines("a", "b", "C", "d", "e"))
            == .conflicted)
    }

    @Test func oneSideDeletingWhatTheOtherEditsConflicts() {
        let base = lines("a", "b", "c")
        #expect(TextMerge.merge(base: base, mine: lines("a", "c"), theirs: lines("a", "B", "c")) == .conflicted)
    }

    /// Two different insertions at the same point have no defensible order, so it asks.
    @Test func differentInsertionsAtTheSamePointConflict() {
        let base = lines("a", "b")
        #expect(TextMerge.merge(base: base, mine: lines("mine", "a", "b"), theirs: lines("theirs", "a", "b"))
            == .conflicted)
    }

    // MARK: - Properties

    /// Neither side is privileged: which one is called `mine` cannot change the answer.
    @Test func theMergeIsSymmetric() {
        let base = lines("a", "b", "c", "d", "e")
        let mine = lines("a", "B", "c", "d", "e")
        let theirs = lines("a", "b", "c", "D", "e")
        #expect(TextMerge.merge(base: base, mine: mine, theirs: theirs)
            == TextMerge.merge(base: base, mine: theirs, theirs: mine))
    }

    /// Edits to disjoint regions of a real journal always merge, and the result is what
    /// applying both edits by hand produces. Run over the corpus so the shapes are the ones
    /// the file actually has.
    @Test func disjointEditsOfTheCorpusAlwaysMergeToBothEdits() {
        var generator = SeededGenerator(seed: 0x5EED)
        let baseLines = Corpus.text.components(separatedBy: "\n")

        for _ in 0..<200 {
            // Two ranges with at least one untouched line between them, so they are genuinely
            // disjoint rather than merely different.
            let first = Int.random(in: 0..<(baseLines.count / 2), using: &generator)
            let second = Int.random(in: (baseLines.count / 2 + 1)..<baseLines.count, using: &generator)

            var mineLines = baseLines
            mineLines[first] = "- edited here \(first)"
            var theirLines = baseLines
            theirLines[second] = "- edited there \(second)"

            var bothLines = baseLines
            bothLines[first] = "- edited here \(first)"
            bothLines[second] = "- edited there \(second)"

            let merged = TextMerge.merge(
                base: Corpus.text,
                mine: mineLines.joined(separator: "\n"),
                theirs: theirLines.joined(separator: "\n")
            )
            #expect(merged == .merged(bothLines.joined(separator: "\n")))
        }
    }

    /// A merge never invents a line. Whatever comes out was in one of the three inputs, which
    /// is the property that makes applying one unattended defensible at all.
    @Test func aMergeOnlyEverEmitsLinesItWasGiven() {
        var generator = SeededGenerator(seed: 0xC0FFEE)
        let baseLines = Corpus.text.components(separatedBy: "\n")

        for _ in 0..<200 {
            var mineLines = baseLines
            var theirLines = baseLines
            for _ in 0..<3 {
                mineLines[Int.random(in: 0..<mineLines.count, using: &generator)] = "- mine \(Int.random(in: 0..<99, using: &generator))"
                theirLines[Int.random(in: 0..<theirLines.count, using: &generator)] = "- theirs \(Int.random(in: 0..<99, using: &generator))"
            }

            let known = Set(baseLines).union(mineLines).union(theirLines)
            switch TextMerge.merge(
                base: Corpus.text,
                mine: mineLines.joined(separator: "\n"),
                theirs: theirLines.joined(separator: "\n")
            ) {
            case .merged(let text):
                #expect(text.components(separatedBy: "\n").allSatisfy { known.contains($0) })
            case .conflicted:
                break
            }
        }
    }
}

/// Deterministic randomness: a failing case has to be reproducible from the seed alone.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
