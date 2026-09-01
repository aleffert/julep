import XCTest

/// Base for the macOS UI tests: seeds a journal on disk and launches the app pointed at it.
///
/// The app is sandboxed, so the seeded journal has to live somewhere it is allowed to read.
/// Its own container is the one place both the app and the (unsandboxed) test runner can
/// reach, which is why these do not use `/tmp` the way the iOS tests do.
class MacJournalUITestCase: XCTestCase {
    var app: XCUIApplication!
    private var containerPath: String!

    private static let sandboxRoot = FileManager.default
        .homeDirectoryForCurrentUser
        .appending(path: "Library/Containers/com.quipsoteric.julep/Data/tmp/uitests")

    override func setUp() {
        continueAfterFailure = false
    }

    @discardableResult
    func launch(journal: String) -> XCUIApplication {
        let directory = Self.sandboxRoot.appending(path: UUID().uuidString)
        containerPath = directory.path(percentEncoded: false)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try! journal.write(to: directory.appending(path: "journal.txt"),
                           atomically: true, encoding: .utf8)

        app = XCUIApplication()
        app.launchArguments = ["--local-container", containerPath]
        app.launch()
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

    func journalOnDisk() -> String {
        (try? String(contentsOf: URL(filePath: containerPath).appending(path: "journal.txt"),
                     encoding: .utf8)) ?? ""
    }

    func waitForJournalOnDisk(toContain needle: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if journalOnDisk().contains(needle) { return true }
            Thread.sleep(forTimeInterval: 0.15)
        }
        return false
    }

    /// Puts the caret at the very end of the text, the only position placeable reliably.
    func focusEditorAtEnd() {
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.click()
        app.typeKey(.downArrow, modifierFlags: .command)
    }
}
