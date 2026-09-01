import Foundation
import Testing
@testable import JulepKit

@Suite("Grammar")
struct GrammarTests {
    /// The corpus is eight months of real journal. If the grammar is right, none of it is
    /// a mystery -- and anything it cannot read shows up here rather than being mangled.
    @Test func corpusHasNoUnknownLines() {
        let document = Document(Corpus.text)
        let unknown = document.lines.enumerated().filter { $0.element.kind == .unknown }
        #expect(unknown.isEmpty, "unrecognized: \(unknown.map { "line \($0.offset + 1): \($0.element.raw)" })")
    }

    @Test func classifiesEachKindOfLine() {
        #expect(Grammar.classify("sunday 8/30/2026")
            == .dayHeader(DayHeader(weekday: .sunday, month: 8, day: 30, year: 2026)))
        #expect(Grammar.classify("done") == .sectionLabel(.done))
        #expect(Grammar.classify("next") == .sectionLabel(.next))
        #expect(Grammar.classify("delta 5 days") == .delta(days: 5))
        #expect(Grammar.classify("delta 1 day") == .delta(days: 1))
        #expect(Grammar.classify("") == .blank)
        #expect(Grammar.classify("   ") == .blank)
        #expect(Grammar.classify("* an older convention") == .unknown)
    }

    /// Leading whitespace carries no meaning -- there is no nesting in this format.
    @Test("Indentation does not change what a line is", arguments: ["", " ", "  ", "\t"])
    func indentationIsIgnored(_ indent: String) {
        #expect(Grammar.classify(indent + "done") == .sectionLabel(.done))
        #expect(Grammar.classify(indent + "delta 2 days") == .delta(days: 2))
        guard case .item(let item) = Grammar.classify(indent + "- unpack") else {
            Issue.record("expected an item"); return
        }
        #expect(item.text == "unpack")
    }

    @Test func itemTextIsTakenVerbatim() {
        let raw = "- book the annual checkup 555.019.4471 (https://example.com/a(b)c) -- soon"
        guard case .item(let item) = Grammar.classify(raw) else {
            Issue.record("expected an item"); return
        }
        #expect(item.text == "book the annual checkup 555.019.4471 (https://example.com/a(b)c) -- soon")
        #expect(item.tag == nil)
        #expect(item.annotation == nil)
    }

    @Test func emptyItemIsStillAnItem() {
        #expect(Grammar.classify("- ") == .item(Item(text: "")))
        #expect(Grammar.classify("-") == .item(Item(text: "")))
    }
}

@Suite("Tags and annotations")
struct ItemDetailTests {
    @Test func tagIsReadOnlyAtTheStart() {
        guard case .item(let tagged) = Grammar.classify("- [orchid] record walkthrough") else {
            Issue.record("expected an item"); return
        }
        #expect(tagged.tag?.name == "orchid")
        #expect(tagged.tag?.span == Span(location: 2, length: 8))

        // Brackets later in the line are ordinary characters.
        guard case .item(let untagged) = Grammar.classify("- record walkthrough [orchid]") else {
            Issue.record("expected an item"); return
        }
        #expect(untagged.tag == nil)
    }

    /// The corpus has `[field notes]`.
    @Test func tagsMayContainSpaces() {
        guard case .item(let item) = Grammar.classify("- [field notes] call the lab") else {
            Issue.record("expected an item"); return
        }
        #expect(item.tag?.name == "field notes")
    }

    @Test func annotationArgumentIsCaptured() {
        guard case .item(let item) = Grammar.classify("- harass landlord @schedule(9/8/2026)") else {
            Issue.record("expected an item"); return
        }
        #expect(item.annotation?.argument == "9/8/2026")
        #expect(item.annotation?.span == Span(location: 18, length: 19))
    }

    /// Item text contains parenthesized URLs, so the scan matches by depth rather than
    /// stopping at the first `)`.
    @Test func annotationHandlesNestedParentheses() {
        guard case .item(let item) = Grammar.classify("- thing @schedule(every 2 weeks (from monday))") else {
            Issue.record("expected an item"); return
        }
        #expect(item.annotation?.argument == "every 2 weeks (from monday)")
    }

    @Test func unterminatedAnnotationIsNotAnAnnotation() {
        guard case .item(let item) = Grammar.classify("- thing @schedule(tuesday") else {
            Issue.record("expected an item"); return
        }
        #expect(item.annotation == nil)
    }

    @Test func tagAndAnnotationCoexist() {
        guard case .item(let item) = Grammar.classify("- [quarry] renew passport @schedule(in 3 weeks)") else {
            Issue.record("expected an item"); return
        }
        #expect(item.tag?.name == "quarry")
        #expect(item.annotation?.argument == "in 3 weeks")
    }
}
