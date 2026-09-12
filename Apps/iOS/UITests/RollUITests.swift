import XCTest

final class RollUITests: JournalUITestCase {
    private func rollNow(journal: String) {
        launch(journal: journal)
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))
        element("nav.roll").tap()
    }

    /// roll-carry: one action, no prompts. Everything open comes forward.
    func testRollCarriesEverythingInOneAction() {
        rollNow(journal: """
        sunday 8/30/2026
        - chase down the rebate
        next
        - harass landlord
        """)
        XCTAssertTrue(waitForJournalOnDisk(toContain: "delta "), "got: \(journalOnDisk())")

        let text = journalOnDisk()
        XCTAssertTrue(text.contains("- chase down the rebate"))
        XCTAssertTrue(text.contains("- harass landlord"))
        XCTAssertFalse(text.hasPrefix("sunday 8/30/2026"), "the new block should come first")
        // Nothing was asked.
        XCTAssertFalse(app.buttons["roll.carry"].exists)
    }

    /// derived-header: the weekday and delta are computed, never typed.
    func testRollWritesADerivedHeaderAndDelta() {
        rollNow(journal: "sunday 8/30/2026\n- chase down the rebate")
        XCTAssertTrue(waitForJournalOnDisk(toContain: "delta "), "got: \(journalOnDisk())")
    }

    /// roll-injects-due: something deferred to a date now past enters the new block.
    func testDueDeferralsAreInjected() {
        rollNow(journal: """
        sunday 8/30/2026
        - a thing

        wednesday 7/1/2026
        - renew passport @schedule(8/1/2026)
        """)
        XCTAssertTrue(waitForJournalOnDisk(toContain: "- renew passport"),
                      "got: \(journalOnDisk())")
    }

    /// An annotated item is a decision already made: its line stays put and is not carried.
    ///
    /// The deferral has to still be ahead of today, or it is due -- and a due deferral is
    /// *supposed* to enter the new block, which is what `testDueDeferralsAreInjected` covers.
    func testAnnotatedItemsAreNotCarried() {
        let due = dateNotYetDue()
        rollNow(journal: "sunday 8/30/2026\n- chase down the rebate @schedule(\(due))")
        XCTAssertTrue(waitForJournalOnDisk(toContain: "delta "), "got: \(journalOnDisk())")

        let text = journalOnDisk()
        XCTAssertTrue(text.contains("- chase down the rebate @schedule(\(due))"),
                      "the annotated line should stay where it was written")
        XCTAssertEqual(text.components(separatedBy: "chase down the rebate").count - 1, 1,
                       "it should not also be carried forward")
    }
}

final class ScheduleUITests: JournalUITestCase {
    /// schedule-view: a deferral months out is verifiable rather than an act of faith.
    ///
    /// The date has to still be ahead of today: a row renders its due date only until the
    /// deferral comes due, and reads "due now" from then on.
    func testScheduledItemsAreListedWithTheirDates() {
        let due = dateNotYetDue(inDays: 90)
        launch(journal: """
        monday 8/31/2026
        - a thing
        - renew passport @schedule(\(due))
        - pay rent @schedule(every month)
        """)
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))
        element("nav.schedule").tap()

        XCTAssertTrue(app.staticTexts["renew passport"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["pay rent"].exists)

        // The one-shot shows its concrete date; the repeat shows its rule.
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", due)
        ).firstMatch.exists, "the deferral's date is not shown")
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Every month")
        ).firstMatch.exists, "the repeat's rule is not shown")
    }

    /// An annotation is the deferral, so it counts the moment it is written -- there is no
    /// second state it has to reach first, and nothing that has to happen at a roll.
    func testAnAnnotationCountsAsSoonAsItIsWritten() {
        launch(journal: "monday 8/31/2026\n- renew passport @schedule(\(dateNotYetDue(inDays: 90)))")
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))
        element("nav.schedule").tap()

        XCTAssertTrue(app.staticTexts["renew passport"].waitForExistence(timeout: 5),
                      "a deferral written in the journal is invisible")
        XCTAssertFalse(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Files at next roll")
        ).firstMatch.exists, "nothing is filed any more; there is only the journal")
    }

    /// The list must be closable.
    func testTheScheduleListCanBeDismissed() {
        launch(journal: "monday 8/31/2026\n- a thing")
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))
        element("nav.schedule").tap()
        XCTAssertTrue(element("schedule.done").waitForExistence(timeout: 5))
        element("schedule.done").tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 5))
    }

    /// natural-dates: what gets written is concrete, never "friday".
    ///
    /// Further out than the day after the block on purpose: a one-day deferral is filed
    /// under `next` rather than written, which is the test below.
    func testATypedNaturalDateIsRewrittenConcrete() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        editor.typeText(" @schedule(friday)")

        XCTAssertFalse(editorText.contains("@schedule(friday)"),
                       "natural language should not survive in the file: \(editorText)")
        XCTAssertTrue(editorText.contains("@schedule("))
        XCTAssertNotNil(try? Regex(#"@schedule\(\d{1,2}/\d{1,2}/\d{4}\)"#))
    }

    /// A deferral to the day after the block is what `next` already means, so the item is
    /// filed there and the annotation dropped. This is the inline way to add a `next` item,
    /// which on iOS is the only quick one: the `@schedule(` picker is right there on the
    /// toolbar and a section label is not.
    func testADeferralToTheDayAfterIsFiledIntoNext() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        editor.typeText(" @schedule(tuesday)")

        XCTAssertTrue(editorText.contains("next\n- renew passport"),
                      "the item was not filed into next: \(editorText)")
        XCTAssertFalse(editorText.contains("@schedule("),
                       "the annotation should be gone: \(editorText)")
    }

    /// The picked date has to land in the annotation being typed.
    ///
    /// The sheet has no idea where the caret is, and searching the text for the last
    /// `@schedule(` finds whichever sits lowest in the file -- which, with blocks
    /// newest-first, is an *older* annotation further down.
    func testThePickedDateLandsAtTheCaretNotTheLastAnnotation() {
        // Several items at the top so the tap below lands on one whichever line it hits.
        // An annotation only completes on an item, so a tap that strays onto the blank line
        // or the header would be testing nothing.
        launch(journal: """
        monday 8/31/2026
        - renew passport
        - water the plants
        - call the bank
        - book the flight

        sunday 8/30/2026
        - an older thing @schedule(12/1/2026)
        """)
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))

        // Somewhere in the upper block -- the exact line does not matter, only that it is not
        // the last annotation in the file.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        editor.typeText(" @schedule(")
        let option = element("picker.option.every week")
        XCTAssertTrue(option.waitForExistence(timeout: 5),
                      "typing the annotation did not open the suggestions")
        option.tap()

        // The older annotation, which sits lowest in the file, must be untouched -- it is
        // what a backwards search would have found.
        XCTAssertTrue(editorText.contains("- an older thing @schedule(12/1/2026)"),
                      "the pick landed on the last annotation, not the caret: \(editorText)")
        XCTAssertEqual(editorText.components(separatedBy: "every week").count - 1, 1,
                       "the argument was inserted more than once: \(editorText)")
    }

    /// The gutter and the highlighter both hang off TextKit 2. The Mac shell silently fell
    /// back to TextKit 1 once and simply stopped drawing either, with no error anywhere.
    func testTheEditorIsStillOnTextKitTwo() {
        launch(journal: "monday 8/31/2026\n- chase down the rebate")
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))
        // Marks come from layout fragments, so their presence is the observable proof.
        XCTAssertTrue(element("gutter.done.1").waitForExistence(timeout: 5),
                      "no gutter marks: the editor is not on TextKit 2")
    }

    /// inline-picker: the toolbar opens the annotation and the strip finishes it, so no
    /// parentheses or digits are typed.
    func testTheToolbarButtonOpensTheSuggestions() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()

        app.buttons["toolbar.schedule"].tap()

        // Choosing a repeat writes it verbatim, closing the annotation.
        let repeatButton = element("picker.option.every 2 weeks")
        XCTAssertTrue(repeatButton.waitForExistence(timeout: 5),
                      "the repeat options are not on the strip")
        repeatButton.tap()
        XCTAssertTrue(editorText.contains("@schedule(every 2 weeks)"), "got: \(editorText)")
    }

    /// The calendar takes the keyboard's place rather than arriving as a sheet, which is what
    /// keeps the caret -- and so the annotation being written -- where the user left it.
    func testACalendarDateLandsInTheAnnotation() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()

        app.buttons["toolbar.schedule"].tap()
        let date = element("picker.date")
        XCTAssertTrue(date.waitForExistence(timeout: 5),
                      "no way to reach a date the suggestions do not cover")
        date.tap()

        // The confirm button names the day it would write, so the assertion can read it
        // rather than guess what the calendar opened on.
        let use = element("picker.date.use")
        XCTAssertTrue(use.waitForExistence(timeout: 5), "the calendar did not open")
        let argument = use.label.replacingOccurrences(of: "Use ", with: "")
        use.tap()

        XCTAssertTrue(editorText.contains("@schedule(\(argument))"), "got: \(editorText)")
    }

    /// Cancelling writes nothing, and leaves the annotation open for another answer.
    func testCancellingTheCalendarWritesNothing() {
        launch(journal: "monday 8/31/2026\n- renew passport")
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()

        app.buttons["toolbar.schedule"].tap()
        element("picker.date").tap()
        XCTAssertTrue(element("picker.date.cancel").waitForExistence(timeout: 5))
        element("picker.date.cancel").tap()

        XCTAssertTrue(editorText.contains("- renew passport @schedule("),
                      "the opening was lost: \(editorText)")
        XCTAssertFalse(editorText.contains(")"), "something was written: \(editorText)")
        // By insertion, not by label: "Tomorrow" is written as the date it means, so a
        // repeat -- written verbatim -- is the one suggestion with a stable identifier.
        XCTAssertTrue(element("picker.option.every week").waitForExistence(timeout: 5),
                      "the suggestions did not come back")
    }
}
