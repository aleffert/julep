import Foundation

/// Reads and writes one text file through `NSFileCoordinator`, and reports changes made to
/// it by anything else -- the other device, Finder, or a text editor.
///
/// Coordination is not optional here. The journal is a plain file in iCloud Drive that the
/// user is explicitly invited to edit in other tools, so uncoordinated access would race with
/// both the sync daemon and whatever else has it open.
public final class CoordinatedTextFile: NSObject, NSFilePresenter, @unchecked Sendable {
    public let fileURL: URL
    private let queue: OperationQueue
    private let lock = NSLock()
    private var changeHandler: (@Sendable () -> Void)?
    private var isObserving = false

    public init(fileURL: URL) {
        self.fileURL = fileURL
        queue = OperationQueue()
        queue.name = "julep.file-presenter.\(fileURL.lastPathComponent)"
        queue.maxConcurrentOperationCount = 1
        super.init()
    }

    deinit {
        if isObserving { NSFileCoordinator.removeFilePresenter(self) }
    }

    // MARK: - Reading and writing

    /// A missing file reads as empty rather than throwing -- an empty journal is a legitimate
    /// starting state, not an error.
    public func read() throws -> String {
        var result: Result<String, Error> = .success("")
        var coordinationError: NSError?

        NSFileCoordinator(filePresenter: self)
            .coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
                result = Result {
                    guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
                    else { return "" }
                    return try String(contentsOf: url, encoding: .utf8)
                }
            }

        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    public func write(_ text: String) throws {
        var writeError: Error?
        var coordinationError: NSError?

        NSFileCoordinator(filePresenter: self)
            .coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinationError) { url in
                do {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    writeError = error
                }
            }

        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
    }

    // MARK: - Observation

    /// Starts reporting external changes. The handler runs off the main thread.
    public func startObserving(onChange handler: @escaping @Sendable () -> Void) {
        lock.withLock {
            changeHandler = handler
            guard !isObserving else { return }
            isObserving = true
            NSFileCoordinator.addFilePresenter(self)
        }
    }

    public func stopObserving() {
        lock.withLock {
            changeHandler = nil
            guard isObserving else { return }
            isObserving = false
            NSFileCoordinator.removeFilePresenter(self)
        }
    }

    // MARK: - NSFilePresenter

    public var presentedItemURL: URL? { fileURL }
    public var presentedItemOperationQueue: OperationQueue { queue }

    public func presentedItemDidChange() {
        let handler = lock.withLock { changeHandler }
        handler?()
    }
}
