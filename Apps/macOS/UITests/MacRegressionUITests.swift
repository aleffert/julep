import XCTest

/// Reproductions of things that broke in real use.
final class MacRegressionUITests: MacJournalUITestCase {
    private static let journal = """
    monday 8/31/2026
    - renew passport
    - water the plants
    done
    - unpack

    delta 1 day

    sunday 8/30/2026
    - chase down the rebate
    """

    /// Typing the word `@schedule` must not disturb anything: no lost text, no caret jump.
    /// Reported as "the insertion point moves to the bottom and stuff gets deleted".
    func testTypingTheAnnotationKeywordLosesNothing() {
        launch(journal: Self.journal)
        focusEditorAtEnd()

        editor.typeText(" @schedule")

        let text = editorText
        XCTAssertTrue(text.hasPrefix("monday 8/31/2026"), "the head of the journal changed: \(text)")
        XCTAssertTrue(text.contains("- water the plants"), "an untouched line vanished: \(text)")
        XCTAssertTrue(text.contains("delta 1 day"), "an untouched line vanished: \(text)")
        XCTAssertTrue(text.contains("sunday 8/30/2026"), "an untouched line vanished: \(text)")
        XCTAssertTrue(text.hasSuffix("- chase down the rebate @schedule"),
                      "the typing did not land where the caret was: \(text)")
    }

    /// And through the opening paren, which is what triggers the picker.
    func testTypingThroughTheOpeningParenLosesNothing() {
        launch(journal: Self.journal)
        focusEditorAtEnd()

        editor.typeText(" @schedule(")

        let text = editorText
        XCTAssertTrue(text.contains("- water the plants"), "an untouched line vanished: \(text)")
        XCTAssertTrue(text.contains("sunday 8/30/2026"), "an untouched line vanished: \(text)")
        XCTAssertTrue(text.hasSuffix("- chase down the rebate @schedule("),
                      "the typing did not land where the caret was: \(text)")
    }

    /// Puts the caret at the end of `- renew passport`, the second line, without relying on
    /// clicking at a computed coordinate.
    private func focusEndOfSecondLine() {
        focusEditorAtEnd()
        for _ in 0..<8 { app.typeKey(.upArrow, modifierFlags: []) }
        app.typeKey(.rightArrow, modifierFlags: .command)
    }

    /// The reported symptom is a caret that jumps to the bottom, which only makes sense if
    /// the edit was happening somewhere other than where the caret was.
    func testTypingMidDocumentStaysWhereTheCaretIs() {
        launch(journal: Self.journal)
        focusEndOfSecondLine()

        editor.typeText(" @schedule(9/8/2026)")

        let text = editorText
        XCTAssertTrue(text.contains("- renew passport @schedule(9/8/2026)"),
                      "the edit did not land on the caret's line: \(text)")
        XCTAssertTrue(text.contains("- water the plants"), "an untouched line vanished: \(text)")
        XCTAssertTrue(text.hasSuffix("- chase down the rebate"),
                      "the end of the journal changed: \(text)")
    }

    /// Same, stopping at the opening paren where the picker appears.
    func testTypingMidDocumentThroughTheParenLosesNothing() {
        launch(journal: Self.journal)
        focusEndOfSecondLine()

        editor.typeText(" @schedule(")

        let text = editorText
        XCTAssertTrue(text.contains("- renew passport @schedule("),
                      "the edit did not land on the caret's line: \(text)")
        XCTAssertTrue(text.contains("- water the plants"), "an untouched line vanished: \(text)")
        XCTAssertTrue(text.hasSuffix("- chase down the rebate"),
                      "the end of the journal changed: \(text)")
    }

    /// Reported: with an annotation already on one line, starting a new item and typing
    /// `@schedule` on it makes the new line's text disappear.
    func testASecondAnnotationDoesNotEatTheLineItIsOn() {
        launch(journal: "monday 8/31/2026\n- renew passport @schedule(9/8/2026)")
        focusEditorAtEnd()

        editor.typeText("\n")
        editor.typeText("call the vet")
        editor.typeText(" @schedule")

        let text = editorText
        XCTAssertTrue(text.contains("- call the vet @schedule"),
                      "the new line lost its text: \(text)")
        XCTAssertTrue(text.contains("- renew passport @schedule(9/8/2026)"),
                      "the first annotation was disturbed: \(text)")
    }

    /// The same, carried through the opening paren.
    func testASecondAnnotationSurvivesItsOpeningParen() {
        launch(journal: "monday 8/31/2026\n- renew passport @schedule(9/8/2026)")
        focusEditorAtEnd()

        editor.typeText("\n")
        editor.typeText("call the vet")
        editor.typeText(" @schedule(")

        let text = editorText
        XCTAssertTrue(text.contains("- call the vet @schedule("),
                      "the new line lost its text: \(text)")
        XCTAssertTrue(text.contains("- renew passport @schedule(9/8/2026)"),
                      "the first annotation was disturbed: \(text)")
    }

    /// And all the way through a completed second annotation.
    func testTwoAnnotationsCanCoexist() {
        launch(journal: "monday 8/31/2026\n- renew passport @schedule(9/8/2026)")
        focusEditorAtEnd()

        editor.typeText("\ncall the vet @schedule(9/9/2026)")

        let text = editorText
        XCTAssertTrue(text.contains("- renew passport @schedule(9/8/2026)"), "got: \(text)")
        XCTAssertTrue(text.contains("- call the vet @schedule(9/9/2026)"), "got: \(text)")
    }

    /// A roll rewrites the journal wholesale. Doing that outside the text view's editing
    /// machinery left it out of the undo stack entirely -- a one-way door on the user's file.
    func testARollCanBeUndone() {
        let journal = "sunday 8/30/2026\n- chase down the rebate"
        launch(journal: journal)
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        // The seeded journal has to be on screen before the toolbar means anything.
        XCTAssertTrue(editorText.contains("chase down the rebate"), "the journal never loaded")

        element("nav.roll").click()
        XCTAssertTrue(waitForJournalOnDisk(toContain: "delta "), "the roll did not happen")

        editor.click()
        app.typeKey("z", modifierFlags: .command)

        XCTAssertEqual(editorText, journal, "undo did not take the roll back")
    }

    /// A roll is one edit to one file, so one undo takes all of it back.
    ///
    /// It used to write the journal *and* a schedule store, and reverting only the text left
    /// an item back in the journal while still filed as deferred -- the two disagreeing,
    /// which is worse than not undoing at all. Deferrals are read out of the journal now, so
    /// that disagreement has nowhere to live.
    func testOneUndoTakesBackARollEntirely() {
        // Still ahead of today, so the roll carries nothing and the only edit is the roll
        // itself. A deferral already due is injected into the new block, which is a second
        // thing for the undo to take back and not what this covers.
        let journal = "sunday 8/30/2026\n- chase down the rebate "
            + "@schedule(\(dateNotYetDue(inDays: 90)))"
        launch(journal: journal)
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        XCTAssertTrue(editorText.contains("chase down the rebate"), "the journal never loaded")

        element("nav.roll").click()
        XCTAssertTrue(waitForJournalOnDisk(toContain: "delta "), "the roll did not happen")

        element("nav.schedule").click()
        XCTAssertTrue(app.staticTexts["chase down the rebate"].waitForExistence(timeout: 5))
        element("schedule.done").click()

        // One undo, because there is one file. This used to need the journal and a schedule
        // store reversed together, grouped by hand, and getting that wrong left an item both
        // back in the journal and still filed as deferred.
        editor.click()
        app.typeKey("z", modifierFlags: .command)
        XCTAssertEqual(editorText, journal, "undo did not take the roll back")

        // The schedule went with it, because the schedule *is* the journal.
        element("nav.schedule").click()
        XCTAssertTrue(app.staticTexts["chase down the rebate"].waitForExistence(timeout: 5),
                      "the deferral should be exactly as it was before the roll")
    }

    /// So does accepting a fix-it.
    func testAnAcceptedFixCanBeUndone() {
        let journal = """
        sunday 6/21/2026
        - a thing

        delta 5 days

        tuesday 6/15/2026
        - finish blocking out apartment
        """
        launch(journal: journal)
        XCTAssertTrue(editor.waitForExistence(timeout: 10))

        let mark = element("gutter.diagnostic.5")
        XCTAssertTrue(mark.waitForExistence(timeout: 5), "the bad date was not flagged")
        mark.click()
        app.sheets.buttons["Change the date to 6/16/2026"].click()
        XCTAssertTrue(waitForJournalOnDisk(toContain: "tuesday 6/16/2026"))

        editor.click()
        app.typeKey("z", modifierFlags: .command)

        XCTAssertTrue(editorText.contains("tuesday 6/15/2026"),
                      "undo did not take the fix back: \(editorText)")
    }

    /// The character-eating race only appeared under sustained typing -- it passed once and
    /// failed the next run on identical code -- so this types enough to give it a chance.
    func testSustainedTypingLosesNoCharacters() {
        launch(journal: Self.journal)
        focusEditorAtEnd()

        let typed = " the quick brown fox jumps over the lazy dog @schedule(9/8/2026)"
        editor.typeText(typed)

        XCTAssertTrue(editorText.hasSuffix("- chase down the rebate" + typed),
                      "characters went missing: \(editorText)")
    }

    /// The whole thing, including the rewrite, on a journal with more than one line.
    func testCompletingAnAnnotationLosesNothing() {
        launch(journal: Self.journal)
        focusEditorAtEnd()

        editor.typeText(" @schedule(9/8/2026)")

        let text = editorText
        XCTAssertTrue(text.contains("- water the plants"), "an untouched line vanished: \(text)")
        XCTAssertTrue(text.contains("delta 1 day"), "an untouched line vanished: \(text)")
        XCTAssertTrue(text.hasSuffix("- chase down the rebate @schedule(9/8/2026)"), "got: \(text)")
    }
}
