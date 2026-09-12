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

@Suite("Item marker toggle")
struct ItemMarkerToggleTests {
    /// Writes the toggle's result the way `caret` does, or `nil` where it declines.
    private func toggled(_ input: String) -> String? {
        let (text, selection) = at(input)
        return EditorBehavior.togglingMarker(in: text, at: selection)
            .map { caret($0, in: text) }
    }

    /// Dedenting is about the line, so the caret can be anywhere on it.
    @Test func shiftTabOnAnItemTakesTheMarkerOff() {
        #expect(toggled("- unp|ack") == "unp|ack")
    }

    @Test func shiftTabAtTheStartOfAnItemTakesTheMarkerOff() {
        #expect(toggled("|- unpack") == "|unpack")
    }

    /// Indentation carries no meaning here, so it is not the toggle's to remove.
    @Test func indentationSurvivesTheMarkerComingOff() {
        #expect(toggled("  - unp|ack") == "  unp|ack")
    }

    /// An item emptied out by a toggle or a return is still an item.
    @Test func shiftTabOnABareMarkerTakesItOff() {
        #expect(toggled("-|") == "|")
    }

    @Test func shiftTabAtTheStartOfAPlainLineAddsTheMarker() {
        #expect(toggled("|unpack") == "- |unpack")
    }

    /// Mid-sentence it is far likelier to be a stray keystroke than a request for an item.
    @Test func shiftTabMidSentenceOnAPlainLineDoesNothing() {
        #expect(toggled("unp|ack") == nil)
    }

    @Test func togglingWorksInTheMiddleOfADocument() {
        #expect(toggled("sunday 8/30/2026\n- unp|ack\ndone")
            == "sunday 8/30/2026\nunp|ack\ndone")
        #expect(toggled("sunday 8/30/2026\n|unpack\ndone")
            == "sunday 8/30/2026\n- |unpack\ndone")
    }
}

/// Marks the span an undo restored with `«»`, and writes the text back with `|` where the
/// caret lands -- so the two ends of the rule read side by side.
private func caretAfterUndo(_ marked: String) -> String {
    let start = (marked as NSString).range(of: "«").location
    let stripped = marked.replacingOccurrences(of: "«", with: "") as NSString
    let end = stripped.range(of: "»").location
    let text = stripped.replacingOccurrences(of: "»", with: "")
    let location = EditorBehavior.caret(
        afterUndoRestoring: NSRange(location: start, length: end - start), in: text
    )
    let utf16 = Array(text.utf16)
    return String(decoding: utf16[..<location], as: UTF16.self)
        + "|"
        + String(decoding: utf16[location...], as: UTF16.self)
}

@Suite("Where the caret lands after an undo")
struct UndoCaretTests {
    /// Taking back a tag completion puts back the half-written name, so typing has to carry
    /// on writing it. With the caret left at the front, `[orc` became `[horc`.
    @Test func restoringOneLineLeavesTheCaretAfterIt() {
        #expect(caretAfterUndo("monday 8/31/2026\n- unpack\n- [«orc»")
            == "monday 8/31/2026\n- unpack\n- [orc|")
    }

    /// Taking back a check-off puts back every line the item moved through. The caret
    /// belongs at the change rather than at the far end of the whole day.
    @Test func restoringSeveralLinesLeavesTheCaretAtTheChange() {
        #expect(caretAfterUndo("monday 8/31/2026\n«- unpack\ndone»")
            == "monday 8/31/2026\n|- unpack\ndone")
    }

    /// A deletion taken back selects nothing, and there is no end to move to.
    @Test func restoringNothingLeavesTheCaretWhereItIs() {
        #expect(caretAfterUndo("- unp«»ack") == "- unp|ack")
    }

    /// The selection and the text arrive from different callbacks, so a span reaching past
    /// the end is possible and must not read off the end of the buffer.
    @Test func aSpanPastTheEndFallsBackToItsStart() {
        #expect(EditorBehavior.caret(
            afterUndoRestoring: NSRange(location: 3, length: 99), in: "- unpack"
        ) == 3)
    }
}

@Suite("Prose")
struct ProseTests {
    private func isProse(_ marked: String) -> Bool {
        let (text, selection) = at(marked)
        return EditorBehavior.isProse(in: text, at: selection)
    }

    /// An item is a sentence the user wrote, which is the one place a dictionary belongs.
    @Test func itemTextIsProse() {
        #expect(isProse("- unp|ack"))
        #expect(isProse("- |unpack"))
    }

    /// The structural lines are written in the grammar's language, not English. Autocorrection
    /// capitalizes weekday names, and `Grammar` reads them only lowercase.
    @Test func structuralLinesAreNot() {
        #expect(!isProse("mond|ay 8/31/2026"))
        #expect(!isProse("do|ne"))
        #expect(!isProse("delta 1| day"))
        #expect(!isProse("|"))
    }

    /// A tag name is an identifier: `[work]` and `[Work]` are two different tags.
    @Test func aTagIsNot() {
        #expect(!isProse("- [wo|rk] unpack"))
    }

    @Test func anAnnotationArgumentIsNot() {
        #expect(!isProse("- unpack @schedule(9/8|/2026)"))
    }

    /// The boundary itself is prose, so closing an annotation does not cost the keyboard a
    /// reload for the caret position it lands on.
    @Test func thePositionPastAStructureIsProseAgain() {
        #expect(isProse("- [work]| unpack"))
        #expect(isProse("- unpack @schedule(9/8/2026)|"))
    }

    /// Half-typed, so neither is a span on the line yet -- and this is when the completion
    /// strip is offering the real spellings.
    @Test func oneBeingTypedIsNot() {
        #expect(!isProse("- [wo|"))
        #expect(!isProse("- unpack @schedule(tue|"))
    }

    /// A bracket is only a tag at the start of an item. Anywhere else it is punctuation, and
    /// the sentence around it is still a sentence.
    @Test func aBracketMidSentenceIsProse() {
        #expect(isProse("- see [note| about the boxes"))
    }
}
