import XCTest

/// The AppKit shell, which until now had only ever been compiled.
final class MacEditingUITests: MacJournalUITestCase {
    func testSeededJournalIsDisplayed() {
        launch(journal: "monday 8/31/2026\n- a seeded item")
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertTrue(editorText.contains("a seeded item"), "got: \(editorText)")
    }

    /// no-input-interference on the Mac, where the substitutions are a different set.
    func testNothingIsAutocapitalizedOrSubstituted() {
        launch(journal: "monday 8/31/2026\n- unpack")
        focusEditorAtEnd()
        editor.typeText("\ncall -- \"now\". later")

        XCTAssertTrue(editorText.contains("-- \"now\". later"), "got: \(editorText)")
        XCTAssertFalse(editorText.contains("—"), "dashes were substituted")
        XCTAssertFalse(editorText.contains("\u{201C}"), "quotes were substituted")
        XCTAssertFalse(editorText.contains("Later"), "text was autocapitalized")
    }

    /// item-continuation, wired through `doCommandBy` rather than iOS's delegate hook.
    func testReturnAfterAnItemStartsTheNextItem() {
        launch(journal: "monday 8/31/2026\n- unpack")
        focusEditorAtEnd()
        editor.typeText("\n")
        XCTAssertTrue(editorText.hasSuffix("- unpack\n- "), "got: \(editorText)")

        editor.typeText("water the plants")
        XCTAssertTrue(editorText.hasSuffix("- water the plants"), "got: \(editorText)")
    }

    func testReturnOnAnEmptyItemClearsTheMarker() {
        launch(journal: "monday 8/31/2026\n- unpack")
        focusEditorAtEnd()
        editor.typeText("\n\n")
        XCTAssertTrue(editorText.hasSuffix("- unpack\n"), "got: \(editorText)")
    }

    /// item-toggle from the menu, which is where a Mac expects to find it.
    func testMenuCommandTogglesAnItem() {
        launch(journal: "monday 8/31/2026\n- unpack")
        focusEditorAtEnd()
        editor.typeText("\n\nbring up air conditioner")
        XCTAssertFalse(editorText.contains("- bring up"), "expected a plain line: \(editorText)")

        app.menuBars.menuItems["Toggle Item"].click()
        XCTAssertTrue(editorText.contains("- bring up air conditioner"), "got: \(editorText)")
    }

    func testEditsAreSavedToTheJournalFile() {
        launch(journal: "monday 8/31/2026\n- unpack")
        focusEditorAtEnd()
        editor.typeText("\nfeed the cat")
        XCTAssertTrue(waitForJournalOnDisk(toContain: "feed the cat"), "got: \(journalOnDisk())")
    }

    /// Closing an annotation rewrites its argument concrete. That rewrite must be part of the
    /// same edit, so one undo takes back the whole thing rather than restoring the natural
    /// language and leaving the paren behind.
    func testOneUndoTakesBackTheWholeRewrite() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        focusEditorAtEnd()
        editor.typeText(" @schedule(tuesday)")
        XCTAssertFalse(editorText.contains("@schedule(tuesday)"),
                       "should have been rewritten concrete: \(editorText)")

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(editorText.contains("@schedule(tuesday"),
                      "one undo should restore what was typed: \(editorText)")
        XCTAssertFalse(editorText.contains("@schedule(tuesday)"),
                       "the closing paren went in with the rewrite, so it comes back out too")
    }

    /// The list must not take the keyboard: typing a date out by hand has to still work, and
    /// must not pick up a stray paren from the picker on the way.
    func testTypingContinuesWhileThePickerIsOpen() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        focusEditorAtEnd()
        editor.typeText(" @schedule(")
        editor.typeText("9/8/2026)")

        XCTAssertTrue(editorText.contains("@schedule(9/8/2026)"),
                      "typing was swallowed by the picker: \(editorText)")
    }

    /// The same mechanism, a different convention. Schedule arguments and tag names share
    /// one picker; a test for only one of them would not notice the other falling off.
    func testTheTagListAppearsAfterTypingAnOpenBracket() {
        launch(journal: "monday 8/31/2026\n- [orchid] record walkthrough\n- unpack")
        focusEditorAtEnd()
        editor.typeText("\n[")

        XCTAssertTrue(element("picker.option.orchid").waitForExistence(timeout: 5),
                      "the tag list never dropped down")
    }

    /// Typing narrows it, and what is picked closes the bracket behind it.
    func testATagCanBePickedFromTheList() {
        launch(journal: "monday 8/31/2026\n- [orchid] record walkthrough\n- unpack")
        focusEditorAtEnd()
        editor.typeText("\n[ohl")

        XCTAssertTrue(element("picker.option.orchid").waitForExistence(timeout: 5),
                      "the tag list never dropped down")
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(editorText.hasSuffix("- [orchid] "), "got: \(editorText)")
    }

    /// A bracket that is not in tag position is an ordinary character. Offering to complete
    /// it would invent a convention the grammar does not have.
    func testABracketMidSentenceOffersNothing() {
        launch(journal: "monday 8/31/2026\n- [orchid] record walkthrough\n- unpack")
        focusEditorAtEnd()
        editor.typeText(" [")

        XCTAssertFalse(element("picker.option.orchid").waitForExistence(timeout: 2),
                       "a mid-sentence bracket was treated as a tag")
    }

    /// The list has to actually appear. Asserting only on what completion *produces* let it
    /// be removed entirely without a single test noticing.
    func testTheScheduleListAppearsAfterTypingPauses() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        focusEditorAtEnd()
        editor.typeText(" @schedule(")

        // It waits for a pause, so this waits too.
        XCTAssertTrue(element("picker.option.every week").waitForExistence(timeout: 5),
                      "the schedule list never dropped down")
    }

    /// Picking with the keyboard: arrow down, return.
    func testTheScheduleListIsKeyboardNavigable() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        focusEditorAtEnd()
        editor.typeText(" @schedule(")
        XCTAssertTrue(element("picker.option.every week").waitForExistence(timeout: 5),
                      "the schedule list never dropped down")

        // First entry is "Tomorrow"; one down is "Next week".
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])

        let text = editorText
        XCTAssertTrue(text.contains("@schedule("), "nothing was inserted: \(text)")
        XCTAssertTrue(text.hasSuffix(")"), "the annotation was not closed: \(text)")
        XCTAssertFalse(text.contains("@schedule()"), "an empty argument was written: \(text)")
    }

    /// And not over ordinary journal text.
    func testNoListAppearsWhileTypingOrdinaryText() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        focusEditorAtEnd()
        editor.typeText(" and then some")

        XCTAssertFalse(text(containing: "every").waitForExistence(timeout: 2),
                       "a completion list appeared over ordinary text")
    }

    /// The picker has to keep working. An earlier version cached its presented state in a
    /// property that a dismissal never cleared, so it appeared exactly once per launch.
    func testTheSchedulePickerReopensEveryTime() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        focusEditorAtEnd()

        for attempt in 1...3 {
            editor.typeText(" @schedule(every week)")
            XCTAssertTrue(editorText.contains("@schedule(every week)"),
                          "attempt \(attempt) did not complete: \(editorText)")
            // Clear the line back to the item for the next attempt.
            for _ in 0..<"@schedule(every week) ".count {
                app.typeKey(.delete, modifierFlags: [])
            }
        }
    }
}
