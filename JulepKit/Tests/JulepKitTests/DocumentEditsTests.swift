import Foundation
import Testing
@testable import JulepKit

@Suite("Marking done from the gutter")
struct MarkingDoneTests {
    @Test func movesAnOpenItemIntoAnExistingDoneSection() {
        let document = Document("""
        sunday 8/30/2026
        - chase down the rebate
        done
        - unpack
        """)
        guard let updated = document.markingDone(lineIndex: 1) else {
            Issue.record("no change"); return
        }
        #expect(updated.serialized == """
        sunday 8/30/2026
        done
        - unpack
        - chase down the rebate
        """)
    }

    /// A block with no `done` yet gets one, in the conventional position.
    @Test func createsADoneSectionWhenThereIsNone() {
        let document = Document("""
        sunday 8/30/2026
        - chase down the rebate
        - unpack
        """)
        guard let updated = document.markingDone(lineIndex: 1) else {
            Issue.record("no change"); return
        }
        #expect(updated.serialized == """
        sunday 8/30/2026
        - unpack
        done
        - chase down the rebate
        """)
    }

    /// done belongs before next, even when only next exists.
    @Test func aNewDoneSectionGoesAboveNext() {
        let document = Document("""
        sunday 8/30/2026
        - chase down the rebate
        next
        - harass landlord
        """)
        guard let updated = document.markingDone(lineIndex: 1) else {
            Issue.record("no change"); return
        }
        #expect(updated.serialized == """
        sunday 8/30/2026
        done
        - chase down the rebate
        next
        - harass landlord
        """)
    }

    @Test func anItemFromNextCanBeMarkedDone() {
        let document = Document("""
        sunday 8/30/2026
        - chase down the rebate
        next
        - harass landlord
        """)
        guard let updated = document.markingDone(lineIndex: 3) else {
            Issue.record("no change"); return
        }
        #expect(updated.serialized == """
        sunday 8/30/2026
        - chase down the rebate
        done
        - harass landlord
        next
        """)
    }

    @Test("Nothing happens for lines that cannot be marked done", arguments: [0, 2])
    func nonItemsAreLeftAlone(_ lineIndex: Int) {
        let document = Document("sunday 8/30/2026\n- a thing\ndone\n- already done")
        #expect(document.markingDone(lineIndex: lineIndex) == nil)
    }

    @Test func anAlreadyDoneItemIsLeftAlone() {
        let document = Document("sunday 8/30/2026\n- a thing\ndone\n- already done")
        #expect(document.markingDone(lineIndex: 3) == nil)
    }

    /// On the real journal: the item moves into the block's existing `done`, the file gains
    /// no lines, and nothing outside that block is disturbed.
    @Test func markingDoneOnTheCorpusMovesExactlyOneLine() {
        let document = Document(Corpus.text)
        guard let updated = document.markingDone(lineIndex: 1) else {
            Issue.record("no change"); return
        }
        // A pure move: this block already has a `done`, so no label is added.
        #expect(updated.lines.count == document.lines.count)

        let head = updated.blocks[0]
        #expect(head.openSection == nil, "the only open item left")
        #expect(updated.lines[head.section(.done)!.itemIndices.last!].raw == "- chase down the rebate")

        // Everything from the next block onward is byte-identical.
        let tail = Corpus.text.range(of: "delta 5 days")!
        #expect(updated.serialized.hasSuffix(String(Corpus.text[tail.lowerBound...])))
    }
}

@Suite("Tag collection")
struct TagTests {
    /// Most recently used first, not alphabetical: blocks are newest-first, so first
    /// appearance in the file is recency. The list exists to be picked from quickly, and
    /// alphabetical order buries the two or three tags actually in use.
    @Test func tagsAreOrderedByRecency() {
        let tags = Document(Corpus.text).tags
        #expect(Set(tags) == ["atrium", "field notes", "meadow", "lantern", "orchid",
                              "kiln", "quarry", "harbor", "beacon"])
        // `[orchid]` appears in the second block; `[quarry]` not until much later.
        #expect(tags.first == "orchid")
        #expect(tags.firstIndex(of: "orchid")! < tags.firstIndex(of: "quarry")!)
    }

    @Test func anEmptyJournalHasNoTags() {
        #expect(Document("").tags.isEmpty)
    }
}
