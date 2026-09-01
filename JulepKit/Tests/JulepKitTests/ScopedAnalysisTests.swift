import Foundation
import Testing
@testable import JulepKit

/// The gutter asks about the lines it can draw, not about the journal. That is only sound if
/// a windowed answer is the same answer -- so these check the scoped forms against the full
/// ones rather than against expectations written out by hand.
///
/// The subtle part is that diagnostics are not purely local: a header's date is judged partly
/// by the deltas of the blocks either side. A window that failed to widen for that would look
/// right nearly everywhere, and be wrong exactly where the journal disagrees with itself --
/// which is the case the feature exists for.
@Suite("Scoped analysis")
struct ScopedAnalysisTests {
    private let document = Document(Corpus.text)

    private var windows: [Range<Int>] {
        let count = document.lines.count
        return stride(from: 0, to: count, by: 7).flatMap { start in
            [1, 5, 20, 60].map { start..<min(start + $0, count) }
        }
    }

    @Test func windowedDiagnosticsMatchTheFullAnalysis() {
        let full = Diagnostics.analyze(document)
        for window in windows {
            let expected = full.filter { window.contains($0.lineIndex) }
            #expect(Diagnostics.analyze(document, lines: window) == expected, "window \(window)")
        }
    }

    @Test func windowedMarksMatchTheFullMap() {
        let full = document.gutterMarks(diagnostics: Diagnostics.analyze(document))
        for window in windows {
            let expected = full.filter { window.contains($0.key) }
            #expect(document.gutterMarks(in: window) == expected, "window \(window)")
        }
    }

    @Test func windowedBlocksAreTheRealBlocks() {
        let full = document.blocks
        for window in windows {
            let scoped = document.blocks(intersecting: window, margin: 0)
            // Found from the middle of the file rather than from the top, and identical
            // for it -- ranges, sections, deltas and all.
            for block in scoped { #expect(full.contains(block), "window \(window)") }
            let overlapping = full.filter { $0.range.overlaps(window) }
            #expect(scoped.map(\.headerIndex) == overlapping.map(\.headerIndex), "window \(window)")
        }
    }

    @Test func theMarginReachesTheNeighboursTheDateCheckNeeds() {
        let full = document.blocks
        for window in windows {
            let inner = document.blocks(intersecting: window, margin: 0)
            let widened = document.blocks(intersecting: window, margin: 1)
            guard let first = inner.first, let last = inner.last,
                  let start = full.firstIndex(where: { $0.headerIndex == first.headerIndex }),
                  let end = full.firstIndex(where: { $0.headerIndex == last.headerIndex })
            else { continue }
            if start > 0 {
                #expect(widened.first?.headerIndex == full[start - 1].headerIndex, "\(window)")
            }
            if end + 1 < full.count {
                #expect(widened.last?.headerIndex == full[end + 1].headerIndex, "\(window)")
            }
        }
    }

    /// A journal the grammar finds no headers in still has to answer, and answer nothing.
    @Test func aHeaderlessDocumentHasNoBlocksInAnyWindow() {
        let plain = Document("- one\n- two\n- three")
        #expect(plain.blocks(intersecting: 0..<3).isEmpty)
        #expect(plain.gutterMarks(in: 0..<3).isEmpty)
    }

    /// Ranges the gutter can genuinely hand over: empty, and past the end of a shrinking file.
    @Test func degenerateWindowsAreAnswerable() {
        #expect(Diagnostics.analyze(document, lines: 0..<0).isEmpty)
        #expect(document.gutterMarks(in: 0..<0).isEmpty)
        let past = document.lines.count + 10
        #expect(document.gutterMarks(in: past..<(past + 5)).isEmpty)
    }
}
