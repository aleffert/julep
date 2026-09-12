import XCTest

/// The phone's routes to the operations in `JournalPage`.
@MainActor
final class IOSJournalPage: JournalPage {
    private let fixture = JournalFixture(root: URL(filePath: "/tmp/julep-uitests"))
    private var app: XCUIApplication!

    private var editor: XCUIElement { app.textViews.firstMatch }

    func launch(journal: String) {
        app = fixture.launch(journal: journal)
        _ = editor.waitForExistence(timeout: 10)
        // Tapping below the last line puts the caret at the end, the only position a UI test
        // can place reliably.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
    }

    func type(_ text: String) { editor.typeText(text) }

    /// The keyboard toolbar's button, which writes the `[` and hands the rest to the strip.
    /// Typing one would work too, but the button is the affordance a phone actually offers.
    func openTag() { app.buttons["toolbar.tag"].tap() }

    func openSchedule() { editor.typeText(" \(ScheduleOpening.text)") }

    func offersCompletion(named name: String, timeout: TimeInterval) -> Bool {
        app.buttons["picker.option.\(name)"].waitForExistence(timeout: timeout)
    }

    func acceptCompletion(named name: String) {
        app.buttons["picker.option.\(name)"].tap()
    }

    func undo() { app.buttons["toolbar.undo"].tap() }

    var text: String { editor.value as? String ?? "" }
}
