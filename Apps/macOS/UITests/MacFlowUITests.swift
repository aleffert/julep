import XCTest

/// The AppKit gutter and the flows reached from the window toolbar.
final class MacFlowUITests: MacJournalUITestCase {
    func testClickingTheGutterMarksAnItemDone() {
        launch(journal: """
        monday 8/31/2026
        - chase down the rebate
        done
        - water the plants
        """)
        XCTAssertTrue(editor.waitForExistence(timeout: 10))

        let mark = element("gutter.done.1")
        XCTAssertTrue(mark.waitForExistence(timeout: 5), "no done mark beside the open item")
        mark.click()

        XCTAssertTrue(waitForJournalOnDisk(toContain: "done\n- water the plants\n- chase down the rebate"),
                      "got: \(journalOnDisk())")
    }

    func testDoneItemsHaveNoGutterMark() {
        launch(journal: "monday 8/31/2026\n- chase down the rebate\ndone\n- water the plants")
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertTrue(element("gutter.done.1").waitForExistence(timeout: 5))
        XCTAssertFalse(element("gutter.done.3").exists, "done items should carry no mark")
    }

    /// The app proposes with its reasoning; the file changes only on acceptance.
    func testADiagnosticOffersItsFixAndExplainsWhy() {
        launch(journal: """
        sunday 6/21/2026
        - a thing

        delta 5 days

        tuesday 6/15/2026
        - finish blocking out apartment
        """)
        XCTAssertTrue(editor.waitForExistence(timeout: 10))

        let mark = element("gutter.diagnostic.5")
        XCTAssertTrue(mark.waitForExistence(timeout: 5), "the bad date was not flagged")
        mark.click()

        let explanation = text(containing: "6/15/2026 is a Monday")
        XCTAssertTrue(explanation.waitForExistence(timeout: 5),
                      "the fix was offered without its reasoning")

        // Scoped to the alert: the same button is mirrored into the Touch Bar, which is not
        // clickable and which `firstMatch` will happily pick.
        app.sheets.buttons["Change the date to 6/16/2026"].click()
        XCTAssertTrue(waitForJournalOnDisk(toContain: "tuesday 6/16/2026"), "got: \(journalOnDisk())")
    }

    /// roll-carry: one click, no prompts.
    func testRollCarriesEverythingInOneAction() {
        launch(journal: "sunday 8/30/2026\n- chase down the rebate\nnext\n- harass landlord")
        XCTAssertTrue(editor.waitForExistence(timeout: 10))

        element("nav.roll").click()

        XCTAssertTrue(waitForJournalOnDisk(toContain: "delta "), "got: \(journalOnDisk())")
        let text = journalOnDisk()
        XCTAssertTrue(text.contains("- chase down the rebate"))
        XCTAssertTrue(text.contains("- harass landlord"))
        XCTAssertFalse(text.hasPrefix("sunday 8/30/2026"), "the new block should come first")
    }

    /// A deferral has to be stoppable. `onDelete` alone offers a swipe on iOS and nothing
    /// whatever on macOS, which left an unwanted one stuck in the list for good.
    func testADeferralCanBeStopped() {
        launch(journal: """
        monday 8/31/2026
        - a thing
        - call landlord @schedule(9/1/2026)
        """)
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        element("nav.schedule").click()

        XCTAssertTrue(app.staticTexts["call landlord"].waitForExistence(timeout: 5))
        element("schedule.remove.call landlord").click()

        XCTAssertFalse(app.staticTexts["call landlord"].waitForExistence(timeout: 2),
                       "the item is still listed after being removed")
    }

    /// Stopping a deferral is recorded, not erased. The annotation that created it stays
    /// exactly where it was written; a newer one supersedes it.
    func testStoppingADeferralIsWrittenIntoTheJournal() {
        launch(journal: "monday 8/31/2026\n- renew passport @schedule(12/1/2026)")
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        element("nav.schedule").click()

        XCTAssertTrue(app.staticTexts["renew passport"].waitForExistence(timeout: 5))
        element("schedule.remove.renew passport").click()
        element("schedule.done").click()

        XCTAssertTrue(waitForJournalOnDisk(toContain: "- renew passport @schedule(done)"),
                      "the cancellation was not recorded: \(journalOnDisk())")
        XCTAssertTrue(journalOnDisk().contains("- renew passport @schedule(12/1/2026)"),
                      "the original annotation should still be there")
    }

    /// The schedule list must be closable, and must show deferrals not yet filed.
    func testScheduleListShowsPendingItemsAndCloses() {
        launch(journal: "monday 8/31/2026\n- renew passport @schedule(12/1/2026)")
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        element("nav.schedule").click()

        XCTAssertTrue(app.staticTexts["renew passport"].waitForExistence(timeout: 5),
                      "a deferral that has not been filed yet is invisible")
        element("schedule.done").click()
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
    }

    /// natural-dates: what lands in the file is concrete, never "tuesday".
    func testATypedNaturalDateIsRewrittenConcrete() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        focusEditorAtEnd()
        editor.typeText(" @schedule(tuesday)")

        XCTAssertFalse(editorText.contains("@schedule(tuesday)"),
                       "natural language should not survive: \(editorText)")
        XCTAssertTrue(editorText.contains("@schedule("))
    }

    func testScheduledItemsAreListed() {
        launch(journal: """
        monday 8/31/2026
        - a thing
        - renew passport @schedule(12/1/2026)
        """)
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        element("nav.schedule").click()
        XCTAssertTrue(app.staticTexts["renew passport"].waitForExistence(timeout: 5))
    }
}
