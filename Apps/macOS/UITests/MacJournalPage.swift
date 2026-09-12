import XCTest

/// The Mac's routes to the operations in `JournalPage`.
@MainActor
final class MacJournalPage: JournalPage {
    private let fixture = JournalFixture(root: MacJournalUITestCase.sandboxRoot)
    private var app: XCUIApplication!

    private var editor: XCUIElement { app.textViews.firstMatch }

    func launch(journal: String) {
        app = fixture.launch(journal: journal)
        _ = editor.waitForExistence(timeout: 10)
        editor.click()
        app.typeKey(.downArrow, modifierFlags: .command)
    }

    func type(_ text: String) { editor.typeText(text) }

    /// Typed, because a bracket in tag position is the whole affordance here -- the Mac has
    /// no tag button to reach for.
    func openTag() { editor.typeText("[") }

    func offersCompletion(named name: String, timeout: TimeInterval) -> Bool {
        app.descendants(matching: .any)
            .matching(identifier: "picker.option.\(name)")
            .firstMatch
            .waitForExistence(timeout: timeout)
    }

    /// Clicked rather than taken with Return. Return takes whichever row is highlighted,
    /// which is a weaker claim than "this option can be chosen".
    func acceptCompletion(named name: String) {
        app.descendants(matching: .any)
            .matching(identifier: "picker.option.\(name)")
            .firstMatch
            .click()
    }

    func undo() { app.typeKey("z", modifierFlags: .command) }

    var text: String { editor.value as? String ?? "" }
}
