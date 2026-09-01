import XCTest

final class GutterUITests: JournalUITestCase {
    /// gutter-done: tap in the margin and the item moves into `done`, in the file.
    func testTappingTheGutterMarksAnItemDone() {
        launch(journal: """
        monday 8/31/2026
        - chase down the rebate
        done
        - water the plants
        """)
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))

        let mark = element("gutter.done.1")
        XCTAssertTrue(mark.waitForExistence(timeout: 5), "no done mark beside the open item")
        mark.tap()

        XCTAssertTrue(waitForJournalOnDisk(toContain: "done\n- water the plants\n- chase down the rebate"),
                      "got: \(journalOnDisk())")
    }

    /// Checking an item off is undoable, as it is on the Mac.
    ///
    /// It was not: iOS applied its edits straight to the text storage, which the undo manager
    /// never sees, so the gutter was a one-way door on this platform alone.
    func testCheckingAnItemOffCanBeUndone() {
        launch(journal: "monday 8/31/2026\n- chase down the rebate\ndone\n- water the plants")
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        // Focused, so the accessory toolbar carrying undo is on screen. Shake-to-undo covers
        // the keyboard-down case and cannot be driven from a UI test.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()

        element("gutter.done.1").tap()
        XCTAssertTrue(waitForJournalOnDisk(toContain: "done\n- water the plants\n- chase down the rebate"),
                      "the item never moved: \(journalOnDisk())")

        app.buttons["toolbar.undo"].tap()
        XCTAssertTrue(waitForJournalOnDisk(toContain: "- chase down the rebate\ndone\n- water the plants"),
                      "undo did not put the item back: \(journalOnDisk())")
    }

    /// A `done` item has no mark: there is nothing left to do to it.
    func testDoneItemsHaveNoGutterMark() {
        launch(journal: """
        monday 8/31/2026
        - chase down the rebate
        done
        - water the plants
        """)
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(element("gutter.done.1").waitForExistence(timeout: 5))
        XCTAssertFalse(element("gutter.done.3").exists, "done items should carry no mark")
    }

    /// diagnostics-ui + fix-its: the mark offers the correction with its reasoning, and the
    /// file changes only when it is accepted.
    func testADiagnosticOffersItsFixAndExplainsWhy() {
        launch(journal: """
        sunday 6/21/2026
        - a thing

        delta 5 days

        tuesday 6/15/2026
        - finish blocking out apartment
        """)
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))

        let mark = element("gutter.diagnostic.5")
        XCTAssertTrue(mark.waitForExistence(timeout: 5), "the bad date was not flagged")
        mark.tap()

        // The reasoning is shown, not just a correction.
        let explanation = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "6/15/2026 is a Monday")
        ).firstMatch
        XCTAssertTrue(explanation.waitForExistence(timeout: 5), "no reasoning shown")

        app.buttons["Change the date to 6/16/2026"].tap()
        XCTAssertTrue(waitForJournalOnDisk(toContain: "tuesday 6/16/2026"), "got: \(journalOnDisk())")
    }

    /// The app proposes; the file changes only on acceptance.
    func testDecliningAFixLeavesTheFileAlone() {
        let journal = """
        sunday 6/21/2026
        - a thing

        delta 5 days

        tuesday 6/15/2026
        - finish blocking out apartment
        """
        launch(journal: journal)
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))

        element("gutter.diagnostic.5").tap()
        app.buttons["Leave it"].tap()

        XCTAssertTrue(editorText.contains("tuesday 6/15/2026"), "got: \(editorText)")
        XCTAssertFalse(editorText.contains("6/16/2026"))
    }

    /// An unreadable line is flagged rather than rewritten.
    func testAnUnreadableLineIsFlaggedAndPreserved() {
        launch(journal: """
        monday 8/31/2026
        * a line from some older convention
        """)
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(element("gutter.diagnostic.1").waitForExistence(timeout: 5))
        XCTAssertTrue(editorText.contains("* a line from some older convention"))
    }
}
