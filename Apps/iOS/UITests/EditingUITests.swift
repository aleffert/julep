import XCTest

/// The requirements that only exist at the keyboard.
final class EditingUITests: JournalUITestCase {
    private func editorFocusedAtEnd(journal: String) -> XCUIElement {
        launch(journal: journal)
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        // Tapping below the last line puts the caret at the end of the text, which is the
        // only caret position that can be placed reliably from a UI test.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        return editor
    }

    /// no-input-interference. The journal is uniformly lowercase and autocapitalization is an
    /// active antagonist -- this is the check that it is genuinely off in the built app.
    func testNothingIsAutocapitalized() {
        let editor = editorFocusedAtEnd(journal: "monday 8/31/2026\n- unpack")
        editor.typeText("\nhello. world")
        XCTAssertTrue(editorText.contains("hello. world"), "got: \(editorText)")
        XCTAssertFalse(editorText.contains("Hello"))
        XCTAssertFalse(editorText.contains("World"))
    }

    /// literal-dashes: two dashes must stay two dashes, not become an em dash.
    func testDashesAndQuotesAreNotSubstituted() {
        let editor = editorFocusedAtEnd(journal: "monday 8/31/2026\n- unpack")
        editor.typeText("\ncall -- \"now\"")
        XCTAssertTrue(editorText.contains("-- \"now\""), "got: \(editorText)")
        XCTAssertFalse(editorText.contains("—"))
        XCTAssertFalse(editorText.contains("\u{201C}"))
    }

    /// item-continuation. On iOS this is the whole point: `-` otherwise costs a trip to the
    /// numeric keyboard plane for every single item.
    func testReturnAfterAnItemStartsTheNextItem() {
        let editor = editorFocusedAtEnd(journal: "monday 8/31/2026\n- unpack")
        editor.typeText("\n")
        XCTAssertTrue(editorText.hasSuffix("- unpack\n- "), "got: \(editorText)")

        // ...and typing continues that item.
        editor.typeText("water the plants")
        XCTAssertTrue(editorText.hasSuffix("- water the plants"), "got: \(editorText)")
    }

    /// Return on an empty item ends the list rather than growing an orphan.
    func testReturnOnAnEmptyItemClearsTheMarker() {
        let editor = editorFocusedAtEnd(journal: "monday 8/31/2026\n- unpack")
        editor.typeText("\n")
        editor.typeText("\n")
        XCTAssertTrue(editorText.hasSuffix("- unpack\n"), "got: \(editorText)")
        XCTAssertFalse(editorText.hasSuffix("- "))
    }

    /// keyboard-toolbar: every action the toolbar promises is actually on it.
    func testAccessoryToolbarOffersEveryAction() {
        _ = editorFocusedAtEnd(journal: "monday 8/31/2026\n- [quarry] unpack")
        for identifier in ["toolbar.undo", "toolbar.redo", "toolbar.tag", "toolbar.schedule"] {
            XCTAssertTrue(app.buttons[identifier].exists, "missing \(identifier)")
        }
    }

    /// tag-entry: tags come from the file, and are inserted without typing brackets.
    func testTagsAreOfferedFromTheFile() {
        let editor = editorFocusedAtEnd(journal: "monday 8/31/2026\n- [orchid] record walkthrough")
        editor.typeText("\n")
        app.buttons["toolbar.tag"].tap()

        let option = app.buttons["picker.option.orchid"]
        XCTAssertTrue(option.waitForExistence(timeout: 5),
                      "the strip did not offer the file's tags")
        option.tap()
        XCTAssertTrue(editorText.hasSuffix("- [orchid] "), "got: \(editorText)")
    }

    /// Taking back a tag completion has to leave the caret where the typing left it, so the
    /// next keystroke carries on writing the name rather than landing inside the brackets.
    /// The rule is `EditorBehavior.caret(afterUndoRestoring:in:)`, shared with the Mac; this
    /// is the iOS shell actually collapsing through it.
    func testTypingAfterUndoingATagCompletionContinuesTheName() {
        let editor = editorFocusedAtEnd(
            journal: "monday 8/31/2026\n- [orchid] record walkthrough\n- unpack"
        )
        editor.typeText("\n")
        app.buttons["toolbar.tag"].tap()
        XCTAssertTrue(app.buttons["picker.option.orchid"].waitForExistence(timeout: 5),
                      "the strip offered nothing")
        editor.typeText("orc")

        let option = app.buttons["picker.option.orchid"]
        XCTAssertTrue(option.waitForExistence(timeout: 5), "the strip did not offer the tag")
        option.tap()
        XCTAssertTrue(editorText.hasSuffix("- [orchid] "), "did not complete: \(editorText)")

        app.buttons["toolbar.undo"].tap()
        XCTAssertTrue(editorText.hasSuffix("- [orc"),
                      "undo did not restore what was typed: \(editorText)")

        editor.typeText("h")
        XCTAssertTrue(editorText.hasSuffix("- [orch"),
                      "typing after the undo did not continue the name: \(editorText)")
    }

    /// The handful offered unprompted is a starting point, not the whole list. Typing is how
    /// a tag further down the file is reached, which is the entire reason to type at all.
    func testTypingReachesATagBeyondTheOfferedHandful() {
        let editor = editorFocusedAtEnd(journal: """
        monday 8/31/2026
        - [aa] one
        - [bb] two
        - [cc] three
        - [dd] four
        - [ee] five
        - [ff] six
        - [zebra] seven
        - unpack
        """)
        app.buttons["toolbar.tag"].tap()

        XCTAssertTrue(app.buttons["picker.option.aa"].waitForExistence(timeout: 5),
                      "the strip offered nothing")
        XCTAssertFalse(app.buttons["picker.option.zebra"].exists,
                       "the seventh tag should not be offered unprompted")

        editor.typeText("ze")
        let buried = app.buttons["picker.option.zebra"]
        XCTAssertTrue(buried.waitForExistence(timeout: 5), "typing did not reach it")
        buried.tap()
        XCTAssertTrue(editorText.hasSuffix("- [zebra] unpack"), "got: \(editorText)")
    }

    /// The strip takes the accessory area only while a tag is open, and gives it back.
    func testTheToolbarReturnsAfterATagIsChosen() {
        let editor = editorFocusedAtEnd(journal: "monday 8/31/2026\n- [orchid] record walkthrough")
        editor.typeText("\n")
        XCTAssertTrue(app.buttons["toolbar.undo"].exists, "no toolbar to begin with")

        app.buttons["toolbar.tag"].tap()
        XCTAssertTrue(app.buttons["picker.option.orchid"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["toolbar.undo"].exists, "the strip did not take over")

        app.buttons["picker.option.orchid"].tap()
        XCTAssertTrue(app.buttons["toolbar.undo"].waitForExistence(timeout: 5),
                      "the toolbar never came back")
    }

    /// The edit reaches the file, not just the screen.
    func testEditsAreSavedToTheJournalFile() {
        let editor = editorFocusedAtEnd(journal: "monday 8/31/2026\n- unpack")
        editor.typeText("\nfeed the cat")
        XCTAssertTrue(waitForJournalOnDisk(toContain: "feed the cat"))
    }
}
