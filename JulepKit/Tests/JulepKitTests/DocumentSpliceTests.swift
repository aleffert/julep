import Foundation
import Testing
@testable import JulepKit

/// The invariant that lets the document be the source of truth instead of a view recomputed
/// from a string: a spliced document must be indistinguishable from one parsed from scratch.
///
/// Worth testing hard rather than by example. The editor's text storage and the document are
/// two views of one buffer, and if the splice is wrong they drift silently -- which in this
/// app means writing the wrong bytes to the user's journal.
@Suite("Document splice")
struct DocumentSpliceTests {
    /// Deterministic, so a failure is reproducible. `SystemRandomNumberGenerator` would make
    /// this test tell a different story every run.
    private struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }

    /// What an editor actually produces: typing, deleting, pasting, newlines, and text with
    /// characters outside the basic plane -- which is where a UTF-16 offset bug would show.
    private static let insertions = [
        "", "a", "- ", "\n", "\n- new item", "done", "delta 3 days",
        "monday 9/1/2025", "@schedule(tuesday)", "[tag] ", "  ", "é", "👍",
        "- one\n- two\n- three",
    ]

    private func splice(
        _ text: String, _ range: NSRange, _ replacement: String
    ) -> String {
        (text as NSString).replacingCharacters(in: range, with: replacement)
    }

    @Test func randomEditsMatchAFullReparse() {
        var random = Seeded(state: 0x5EED)
        var document = Document(Corpus.text)
        var text = Corpus.text

        for step in 0..<600 {
            let length = (text as NSString).length
            let location = Int.random(in: 0...length, using: &random)
            let extent = Int.random(in: 0...min(40, length - location), using: &random)
            let range = NSRange(location: location, length: extent)
            // Never split a surrogate pair: a text view cannot produce such a range either,
            // and honouring one would mean inventing a character.
            guard (text as NSString).rangeOfComposedCharacterSequences(for: range) == range
            else { continue }
            let replacement = Self.insertions.randomElement(using: &random)!

            document.replaceCharacters(in: range, with: replacement)
            text = splice(text, range, replacement)

            #expect(document.serialized == text, "diverged at step \(step)")
            #expect(document == Document(text), "kinds diverged at step \(step)")
            #expect(document.utf16Length == (text as NSString).length)
        }
    }

    @Test("Edges a random walk is unlikely to hit", arguments: [
        (NSRange(location: 0, length: 0), "prepended\n"),
        (NSRange(location: 0, length: 6), ""),
        (NSRange(location: 3, length: 0), "\n"),
    ])
    func boundaryEdits(_ range: NSRange, _ replacement: String) {
        let text = "sunday 8/30/2026\n- one\ndone\n- two\n"
        var document = Document(text)
        document.replaceCharacters(in: range, with: replacement)
        let expected = splice(text, range, replacement)
        #expect(document.serialized == expected)
        #expect(document == Document(expected))
    }

    @Test func replacingEverythingIsStillLossless() {
        var document = Document(Corpus.text)
        let whole = NSRange(location: 0, length: (Corpus.text as NSString).length)
        document.replaceCharacters(in: whole, with: "friday 1/2/2026\n- fresh\n")
        #expect(document.serialized == "friday 1/2/2026\n- fresh\n")
    }

    @Test func splicingAnEmptyDocument() {
        var document = Document("")
        document.replaceCharacters(in: NSRange(location: 0, length: 0), with: "- first")
        #expect(document.serialized == "- first")
    }

    /// A paste is one splice, so only the pasted lines are classified -- the point of the
    /// whole exercise. Checked by result rather than by timing: the lines above the paste
    /// must come out of it as the very same values.
    @Test func aSpliceLeavesUntouchedLinesIdentical() {
        var document = Document(Corpus.text)
        let before = document.lines
        let end = (Corpus.text as NSString).length
        document.replaceCharacters(in: NSRange(location: end, length: 0), with: "\n- appended")
        #expect(Array(document.lines.prefix(before.count - 1)) == Array(before.dropLast()))
    }

    @Test func utf16LengthMatchesSerialized() {
        #expect(Document(Corpus.text).utf16Length == (Corpus.text as NSString).length)
        #expect(Document("").utf16Length == 0)
        #expect(Document("a\nb").utf16Length == 3)
    }
}
