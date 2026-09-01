import Foundation
import Testing
@testable import JulepKit

/// Writes the resulting text with `|` marking the caret, so intent is readable at a glance.
private func caret(_ result: EditResult, in original: String) -> String {
    let utf16 = Array(result.applied(to: original).utf16)
    let location = min(result.selection.location, utf16.count)
    return String(decoding: utf16[..<location], as: UTF16.self)
        + "|"
        + String(decoding: utf16[location...], as: UTF16.self)
}

private func at(_ text: String) -> (String, NSRange) {
    let location = text.distance(from: text.startIndex, to: text.firstIndex(of: "|")!)
    var stripped = text
    stripped.remove(at: stripped.firstIndex(of: "|")!)
    let utf16Location = String(stripped.prefix(location)).utf16.count
    return (stripped, NSRange(location: utf16Location, length: 0))
}

@Suite("Item continuation")
struct ItemContinuationTests {
    /// Return at the end of an item hands you the next one already started -- the whole
    /// point on iOS, where `-` costs a trip to the numeric keyboard plane.
    @Test func returnAfterAnItemStartsTheNextOne() {
        let (text, selection) = at("- unpack|")
        #expect(caret(EditorBehavior.newline(in: text, at: selection), in: text) == "- unpack\n- |")
    }

    /// Return on an empty item ends the list instead of growing an orphan.
    @Test func returnOnAnEmptyItemClearsTheMarker() {
        let (text, selection) = at("- unpack\n- |")
        #expect(caret(EditorBehavior.newline(in: text, at: selection), in: text) == "- unpack\n|")
    }

    @Test func returnOnANonItemJustInsertsANewline() {
        let (text, selection) = at("done|")
        #expect(caret(EditorBehavior.newline(in: text, at: selection), in: text) == "done\n|")
    }

    @Test func returnMidItemStillContinuesTheList() {
        let (text, selection) = at("- unp|ack")
        #expect(caret(EditorBehavior.newline(in: text, at: selection), in: text) == "- unp\n- |ack")
    }

    @Test func continuationWorksInTheMiddleOfADocument() {
        let (text, selection) = at("sunday 8/30/2026\n- unpack|\ndone")
        #expect(caret(EditorBehavior.newline(in: text, at: selection), in: text)
            == "sunday 8/30/2026\n- unpack\n- |\ndone")
    }
}
