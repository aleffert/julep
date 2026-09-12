import XCTest

/// One test's journal on disk, and the app pointed at it.
///
/// The two platforms differ only in *where* that file is allowed to live -- the Mac app is
/// sandboxed, so the runner has to seed inside its container, while the simulator shares
/// `/tmp` with the runner outright. Everything after picking the directory is the same, so
/// it is written here rather than once per platform.
@MainActor
final class JournalFixture {
    private let root: URL
    private(set) var containerPath: String = ""

    init(root: URL) {
        self.root = root
    }

    /// Writes `journal` into a directory of its own and launches the app pointed at it.
    @discardableResult
    func launch(journal: String) -> XCUIApplication {
        let directory = root.appending(path: UUID().uuidString)
        containerPath = directory.path(percentEncoded: false)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try! journal.write(to: directory.appending(path: "journal.txt"),
                           atomically: true, encoding: .utf8)

        let app = XCUIApplication()
        app.launchArguments = ["--local-container", containerPath]
        app.launch()
        return app
    }

    /// Retried rather than read once: on the simulator the file has been seen to be briefly
    /// unreadable after the app rewrites it, and a bare read then returns "" -- which a
    /// caller cannot tell apart from a journal that really is empty.
    func onDisk() -> String {
        let url = URL(filePath: containerPath).appending(path: "journal.txt")
        for _ in 0..<20 {
            if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return ""
    }

    /// Writes are debounced, so what is on disk lags the buffer by design.
    func waitForJournal(toContain needle: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if onDisk().contains(needle) { return true }
            Thread.sleep(forTimeInterval: 0.15)
        }
        return false
    }
}
