import Foundation
import Testing
@testable import JulepKit

/// A roll and an accepted fix-it reach the editor as a whole new journal, and are applied as
/// the smallest replacement that produces it. Getting that wrong would corrupt the buffer, so
/// the property is checked against the whole corpus rather than by example.
@Suite("Minimal edit")
struct MinimalEditTests {
    private func applied(_ old: String, _ new: String) -> String {
        guard let edit = EditorBehavior.minimalEdit(from: old, to: new) else { return old }
        return edit.applied(to: old)
    }

    @Test("Any pair round-trips through the edit it produces", arguments: [
        ("", ""),
        ("", "abc"),
        ("abc", ""),
        ("abc", "abc"),
        ("abc", "abd"),
        ("one\ntwo", "one\ninserted\ntwo"),
        ("one\ninserted\ntwo", "one\ntwo"),
        ("tuesday 6/15/2026", "monday 6/15/2026"),
        ("a👍b", "a👍c"),
        ("a👍b", "ab"),
        ("a👍b", "a🎉b"),
        ("café", "cafe"),
        ("\n\n\n", "\n\n"),
    ])
    func pairsRoundTrip(_ old: String, _ new: String) {
        #expect(applied(old, new) == new)
    }

    @Test func identicalTextIsNoEditAtAll() {
        #expect(EditorBehavior.minimalEdit(from: Corpus.text, to: Corpus.text) == nil)
    }

    /// The case that motivated this: a roll prepends, so undoing it should have a caret to
    /// put back rather than the whole journal.
    @Test func aPrependTouchesOnlyTheTop() {
        let rolled = "monday 8/31/2026\n- carried\n\n" + Corpus.text
        guard let edit = EditorBehavior.minimalEdit(from: Corpus.text, to: rolled)
        else { Issue.record("no edit"); return }

        #expect(edit.range == NSRange(location: 0, length: 0))
        #expect(edit.replacement == "monday 8/31/2026\n- carried\n\n")
        #expect(edit.applied(to: Corpus.text) == rolled)
    }

    /// A fix-it rewrites one line, and the edit should be that line -- not the file around it.
    @Test func aSingleLineRewriteTouchesOnlyThatLine() {
        let document = Document(Corpus.text)
        guard let index = document.lines.firstIndex(where: {
            if case .dayHeader = $0.kind { return true }
            return false
        }) else { Issue.record("no header"); return }

        var repaired = document
        repaired.replaceLine(at: index, with: "friday 1/2/2026")
        guard let edit = EditorBehavior.minimalEdit(from: Corpus.text, to: repaired.serialized)
        else { Issue.record("no edit"); return }

        #expect(edit.range.length < 40, "touched \(edit.range.length) characters")
        #expect(edit.applied(to: Corpus.text) == repaired.serialized)
    }

    /// Checking an item off moves one line between two sections of one block. It used to
    /// reach the editor as a whole new journal, which made undoing it select every line.
    @Test func checkingAnItemOffTouchesOnlyItsBlock() {
        let document = Document(Corpus.text)
        let marks = document.gutterMarks(diagnostics: [])
        guard let line = marks.first(where: { $0.value == .openItem })?.key,
              let updated = document.markingDone(lineIndex: line),
              let edit = EditorBehavior.minimalEdit(from: Corpus.text, to: updated.serialized)
        else { Issue.record("no open item in the corpus"); return }

        #expect(edit.applied(to: Corpus.text) == updated.serialized)
        // The block it belongs to, not the file around it.
        guard let block = document.blocks.first(where: { $0.range.contains(line) })
        else { Issue.record("the item is in no block"); return }
        let offsets = document.lineStartOffsets
        let blockStart = offsets[block.range.lowerBound]
        let blockEnd = block.range.upperBound < offsets.count
            ? offsets[block.range.upperBound]
            : document.utf16Length
        #expect(edit.range.location >= blockStart)
        #expect(NSMaxRange(edit.range) <= blockEnd)
    }

    /// Randomized, because the boundary arithmetic is where this would go wrong -- and it
    /// would go wrong by writing the user's journal incorrectly.
    @Test func randomRewritesOfTheCorpusRoundTrip() {
        var random = SystemRandomNumberGenerator()
        let corpus = Corpus.text as NSString
        for _ in 0..<300 {
            let location = Int.random(in: 0...corpus.length, using: &random)
            let length = Int.random(in: 0...min(200, corpus.length - location), using: &random)
            let range = corpus.rangeOfComposedCharacterSequences(
                for: NSRange(location: location, length: length)
            )
            let insertion = ["", "x", "- new\n", "👍", "monday 9/1/2025\n"]
                .randomElement(using: &random)!
            let new = corpus.replacingCharacters(in: range, with: insertion)
            #expect(applied(Corpus.text, new) == new)
        }
    }
}
