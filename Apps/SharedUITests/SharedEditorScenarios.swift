import XCTest

/// Scenarios that have to hold on both shells, written once against `JournalPage`.
///
/// Abstract. This file is compiled into both UI test bundles and XCTest collects every
/// `XCTestCase` it finds, so the base hides its own suite -- otherwise each scenario would
/// also run here, with no driver to run against.
@MainActor
class SharedEditorScenarios: XCTestCase {
    /// The platform's driver. Subclasses return theirs; nothing else about them differs.
    func makePage() -> JournalPage { fatalError("a subclass supplies the driver") }

    /// Built on first use rather than in `setUp`. `XCTestCase.setUp` is nonisolated, so an
    /// override of it cannot reach anything on this main-actor class; the test bodies can.
    private var built: JournalPage?
    var page: JournalPage {
        if let built { return built }
        let page = makePage()
        built = page
        return page
    }

    override class var defaultTestSuite: XCTestSuite {
        self == SharedEditorScenarios.self
            ? XCTestSuite(name: "SharedEditorScenarios (abstract)")
            : super.defaultTestSuite
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private static let journal = """
    monday 8/31/2026
    - [orchid] record walkthrough
    - unpack
    """

    /// Opens a tag on a fresh item and types enough to single out one suggestion.
    private func typeTagPrefix() {
        page.launch(journal: Self.journal)
        page.type("\n")
        page.openTag()
        XCTAssertTrue(page.offersCompletion(named: "orchid"), "the list offered nothing")
        page.type("orc")
        XCTAssertTrue(page.offersCompletion(named: "orchid"), "typing narrowed it away")
    }

    /// What is picked closes the bracket behind it, and leaves room for the item's text.
    func testAcceptingATagClosesItAndLeavesTheCaretReady() {
        typeTagPrefix()
        page.acceptCompletion(named: "orchid")
        XCTAssertTrue(page.text.hasSuffix("- [orchid] "), "got: \(page.text)")
    }

    /// Taking it back restores exactly what was typed -- no more, no less.
    func testUndoingATagCompletionRestoresWhatWasTyped() {
        typeTagPrefix()
        page.acceptCompletion(named: "orchid")
        page.undo()
        XCTAssertTrue(page.text.hasSuffix("- [orc"),
                      "undo did not restore what was typed: \(page.text)")
    }

    /// And leaves the caret where the typing left it, so the next keystroke carries on
    /// writing the name. With the caret restored to the front instead, `[orc` became
    /// `[horc` -- on both shells, which is why this scenario is not written per platform.
    func testTypingAfterUndoingATagCompletionContinuesTheName() {
        typeTagPrefix()
        page.acceptCompletion(named: "orchid")
        page.undo()
        page.type("h")
        XCTAssertTrue(page.text.hasSuffix("- [orch"),
                      "typing after the undo did not continue the name: \(page.text)")
    }
}
