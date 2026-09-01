import Foundation
import Testing
@testable import JulepKit

/// The property everything else rests on: parsing the journal cannot change it.
@Suite("Document round-trip")
struct DocumentRoundTripTests {
    @Test func corpusRoundTripsByteForByte() {
        #expect(Document(Corpus.text).serialized == Corpus.text)
    }

    @Test("Irregular and unrecognized input survives untouched", arguments: [
        "",
        "\n",
        "\n\n\n",
        "no trailing newline",
        "trailing newline\n",
        "  - leading whitespace on an item",
        "- trailing whitespace on an item   ",
        "\t- tab indented",
        "SOMETHING THE GRAMMAR HAS NEVER SEEN",
        "* a bullet from some older convention",
        "sunday 8/30/2026\n- one\ndone\n\n\ndelta 5 days\n\nfriday 8/21/2026\n",
    ])
    func inputRoundTrips(_ text: String) {
        #expect(Document(text).serialized == text)
    }

    @Test func replacingALineLeavesEveryOtherLineAlone() {
        var document = Document(Corpus.text)
        document.replaceLine(at: 1, with: "- something else entirely")
        let original = Corpus.text.components(separatedBy: "\n")
        let updated = document.serialized.components(separatedBy: "\n")

        #expect(updated.count == original.count)
        #expect(updated[1] == "- something else entirely")
        for index in original.indices where index != 1 {
            #expect(updated[index] == original[index])
        }
    }
}
