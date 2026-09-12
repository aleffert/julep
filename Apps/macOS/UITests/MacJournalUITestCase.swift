import XCTest

/// Base for the macOS UI tests: seeds a journal on disk and launches the app pointed at it.
///
/// The app is sandboxed, so the seeded journal has to live somewhere it is allowed to read.
/// Its own container is the one place both the app and the (unsandboxed) test runner can
/// reach, which is why these do not use `/tmp` the way the iOS tests do.
/// `@MainActor` on the base class, which every case inherits: XCUI's element
/// queries and actions are all main-actor isolated, and reaching them from a
/// nonisolated test body is a concurrency violation the compiler now refuses.
@MainActor
class MacJournalUITestCase: XCTestCase {
    var app: XCUIApplication!
    private let fixture = JournalFixture(root: MacJournalUITestCase.sandboxRoot)

    static let sandboxRoot = FileManager.default
        .homeDirectoryForCurrentUser
        .appending(path: "Library/Containers/com.quipsoteric.julep/Data/tmp/uitests")

    override func setUp() {
        continueAfterFailure = false
    }

    @discardableResult
    func launch(journal: String) -> XCUIApplication {
        app = fixture.launch(journal: journal)
        return app
    }

    var editor: XCUIElement { app.textViews.firstMatch }

    var editorText: String {
        editor.value as? String ?? ""
    }

    /// Finds text by content. AppKit exposes an alert's message as `value` rather than
    /// `label`, so both are checked.
    func text(containing needle: String) -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", needle, needle)
        ).firstMatch
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func journalOnDisk() -> String { fixture.onDisk() }

    func waitForJournalOnDisk(toContain needle: String, timeout: TimeInterval = 5) -> Bool {
        fixture.waitForJournal(toContain: needle, timeout: timeout)
    }

    /// Puts the caret at the very end of the text, the only position placeable reliably.
    func focusEditorAtEnd() {
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.click()
        app.typeKey(.downArrow, modifierFlags: .command)
    }
}
