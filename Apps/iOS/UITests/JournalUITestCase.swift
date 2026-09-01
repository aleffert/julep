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
    private var containerPath: String!

    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches with `journal` as the file's contents.
    @discardableResult
    func launch(journal: String) -> XCUIApplication {
        containerPath = "/tmp/julep-uitests/\(UUID().uuidString)"
        let directory = URL(filePath: containerPath)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try! journal.write(to: directory.appending(path: "journal.txt"),
                           atomically: true, encoding: .utf8)

        app = XCUIApplication()
        app.launchArguments = ["--local-container", containerPath]
        app.launch()
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
    func journalOnDisk() -> String {
        let url = URL(filePath: containerPath).appending(path: "journal.txt")
        for _ in 0..<20 {
            if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return ""
    }

    func waitForJournalOnDisk(toContain needle: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if journalOnDisk().contains(needle) { return true }
            Thread.sleep(forTimeInterval: 0.15)
        }
        return false
    }
}
