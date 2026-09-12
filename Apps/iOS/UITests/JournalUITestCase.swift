import XCTest

/// Base for the UI tests: seeds a journal on disk and launches the app pointed at it.
///
/// The app and the test runner share the simulator's filesystem, so a directory under `/tmp`
/// is visible to both. That is what lets a test set up a specific journal -- a block with a
/// known defect, an item carried a known number of times -- instead of poking at whatever
/// happens to be in iCloud.
/// `@MainActor` on the base class, which every case inherits: XCUI's element
/// queries and actions are all main-actor isolated, and reaching them from a
/// nonisolated test body is a concurrency violation the compiler now refuses.
@MainActor
class JournalUITestCase: XCTestCase {
    var app: XCUIApplication!
    private let fixture = JournalFixture(root: URL(filePath: "/tmp/julep-uitests"))

    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches with `journal` as the file's contents.
    @discardableResult
    func launch(journal: String) -> XCUIApplication {
        app = fixture.launch(journal: journal)
        return app
    }

    /// Looks up an element by identifier regardless of the type it reports, since a custom
    /// drawn mark can surface as a button or a plain element depending on its traits.
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The journal as the app currently shows it.
    var editorText: String {
        app.textViews.firstMatch.value as? String ?? ""
    }

    /// The journal as it currently sits on disk, after giving the debounced save a moment.
    func journalOnDisk() -> String { fixture.onDisk() }

    func waitForJournalOnDisk(toContain needle: String, timeout: TimeInterval = 5) -> Bool {
        fixture.waitForJournal(toContain: needle, timeout: timeout)
    }
}
