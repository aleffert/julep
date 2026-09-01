import Foundation
import Testing
@testable import JulepKit

@Suite("Blocks and sections")
struct BlockTests {
    let document = Document(Corpus.text)

    func block(_ header: String) -> Block? {
        document.blocks.first { document.lines[$0.headerIndex].raw == header }
    }

    @Test func everyHeaderBecomesABlock() {
        #expect(document.blocks.count == 52)
    }

    @Test func blocksAreNewestFirst() {
        #expect(document.lines[document.blocks[0].headerIndex].raw == "sunday 8/30/2026")
    }

    /// Section order is not fixed. This block has `next` before `done`, and the parser
    /// tolerates it even though roll writes the conventional order.
    @Test func sectionOrderIsTolerated() {
        guard let block = block("wednesday 7/22/2026") else { Issue.record("missing"); return }
        #expect(block.sections.map(\.label) == [.next, .done])
        #expect(block.openSection == nil)
        #expect(block.section(.next)?.itemIndices.count == 2)
        #expect(block.section(.done)?.itemIndices.count == 3)
    }

    /// All three sections are optional.
    @Test func aBlockCanHaveOnlyOpenItems() {
        guard let block = block("friday 8/21/2026") else { Issue.record("missing"); return }
        #expect(block.sections.map(\.label) == [nil])
        #expect(block.openSection?.itemIndices.count == 4)
    }

    @Test func aBlockCanHaveOnlyDoneItems() {
        guard let block = block("monday 7/13/2026") else { Issue.record("missing"); return }
        #expect(block.sections.map(\.label) == [.done])
        #expect(block.openSection == nil)
    }

    @Test func aBlockCanBeASingleUnlabeledItem() {
        guard let block = block("monday 6/29/2026") else { Issue.record("missing"); return }
        #expect(block.sections.map(\.label) == [nil])
        #expect(block.openSection?.itemIndices.count == 1)
    }

    /// A delta sits above the header of the older block and describes the gap up to the
    /// newer block above it.
    @Test func deltaIsAttachedToTheBlockBelowIt() {
        guard let withDelta = block("tuesday 8/25/2026") else { Issue.record("missing"); return }
        #expect(withDelta.deltaAbove == 5)
        guard let noDelta = block("sunday 8/23/2026") else { Issue.record("missing"); return }
        #expect(noDelta.deltaAbove == nil)
    }

    @Test func blockRangesTileTheFileWithoutOverlap() {
        let blocks = document.blocks
        for (earlier, later) in zip(blocks, blocks.dropFirst()) {
            #expect(earlier.range.upperBound == later.range.lowerBound)
        }
        #expect(blocks.last?.range.upperBound == document.lines.count)
    }
}
