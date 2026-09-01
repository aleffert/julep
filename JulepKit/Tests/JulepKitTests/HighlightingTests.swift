import Foundation
import Testing
@testable import JulepKit

@Suite("Highlighting")
struct HighlightingTests {
    private func roles(_ line: String) -> [HighlightRole] {
        Highlighting.spans(forLine: line).map(\.role)
    }

    @Test func eachKindOfLineIsStyledDistinctly() {
        #expect(roles("sunday 8/30/2026") == [.dayHeader])
        #expect(roles("done") == [.sectionLabel])
        #expect(roles("delta 5 days") == [.delta])
        #expect(roles("* an older convention") == [.unrecognized])
        #expect(roles("") == [])
        #expect(roles("- unpack") == [.itemMarker])
    }

    @Test func tagsAndAnnotationsAreStyledWithinAnItem() {
        #expect(roles("- [orchid] record walkthrough") == [.itemMarker, .tag])
        #expect(roles("- harass landlord @schedule(9/8/2026)") == [.itemMarker, .annotation])
        #expect(roles("- [quarry] renew passport @schedule(in 3 weeks)")
            == [.itemMarker, .tag, .annotation])
    }

    /// Exact offsets, since these become `NSRange`s handed straight to TextKit.
    @Test func spansLandOnTheRightCharacters() {
        let line = "- [orchid] record walkthrough @schedule(9/8/2026)"
        let spans = Highlighting.spans(forLine: line)
        let utf16 = Array(line.utf16)

        func text(_ span: Span) -> String {
            String(decoding: utf16[span.location..<(span.location + span.length)], as: UTF16.self)
        }
        #expect(text(spans[0].span) == "- ")
        #expect(text(spans[1].span) == "[orchid]")
        #expect(text(spans[2].span) == "@schedule(9/8/2026)")
    }

    /// Indentation carries no meaning, so it is left unstyled rather than implying structure.
    @Test func leadingWhitespaceIsNotStyled() {
        let spans = Highlighting.spans(forLine: "   done")
        #expect(spans.map(\.role) == [.sectionLabel])
        #expect(spans[0].span == Span(location: 3, length: 4))
    }

    @Test func trailingWhitespaceIsNotStyled() {
        let spans = Highlighting.spans(forLine: "done   ")
        #expect(spans[0].span == Span(location: 0, length: 4))
    }

    @Test func anEmptyItemStillShowsItsMarker() {
        #expect(Highlighting.spans(forLine: "- ")[0].span == Span(location: 0, length: 2))
        #expect(Highlighting.spans(forLine: "-")[0].span == Span(location: 0, length: 1))
    }

    /// Every line of the corpus produces spans that stay inside the line.
    @Test func everyCorpusSpanIsInBounds() {
        for raw in Corpus.text.components(separatedBy: "\n") {
            let length = raw.utf16.count
            for highlight in Highlighting.spans(forLine: raw) {
                #expect(highlight.span.location >= 0)
                #expect(highlight.span.location + highlight.span.length <= length,
                        "span out of bounds on: \(raw)")
            }
        }
    }

    /// A snapshot of the whole corpus's styling, so a grammar change that quietly alters
    /// what gets highlighted shows up here.
    @Test func corpusHighlightCountsAreStable() {
        var counts: [HighlightRole: Int] = [:]
        for raw in Corpus.text.components(separatedBy: "\n") {
            for highlight in Highlighting.spans(forLine: raw) {
                counts[highlight.role, default: 0] += 1
            }
        }
        #expect(counts[.dayHeader] == 52)
        #expect(counts[.sectionLabel] == 72)   // 48 done + 24 next
        #expect(counts[.delta] == 11)
        #expect(counts[.tag] == 138)
        #expect(counts[.unrecognized] == nil)
        #expect(counts[.annotation] == nil)
    }
}
