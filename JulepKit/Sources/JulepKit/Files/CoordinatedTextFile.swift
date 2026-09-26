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
        try coordinate(.reading) { try Self.contents(of: $0) }
    }

    public func write(_ text: String) throws {
        try coordinate(.writing) { try text.write(to: $0, atomically: true, encoding: .utf8) }
    }

    /// Reads, transforms and writes in one coordinated pass. Returning `nil` from `transform`
    /// leaves the file alone.
    ///
    /// The seam a second process edits the journal through -- the widget rolling it while the
    /// app is not running. A `read()` followed by a separate `write()` leaves a window between
    /// them in which someone else's write lands and is then overwritten, and the journal is the
    /// one file in this app where losing a write is unrecoverable.
    public func update(_ transform: (String) throws -> String?) throws {
        try coordinate(.writing) { url in
            guard let updated = try transform(try Self.contents(of: url)) else { return }
            try updated.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func contents(of url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return "" }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private enum Access {
        case reading
        case writing
    }

    /// The two halves of every coordinated access: the coordinator's own error, and whatever the
    /// accessor threw inside it. Both have to come back out, and the accessor cannot throw
    /// through the coordinator's block.
    private func coordinate<T>(_ access: Access, _ accessor: (URL) throws -> T) throws -> T {
        var result: Result<T, Error>?
        var coordinationError: NSError?
        let coordinator = NSFileCoordinator(filePresenter: self)
        let body: (URL) -> Void = { url in result = Result { try accessor(url) } }

        switch access {
        case .reading:
            coordinator.coordinate(
                readingItemAt: fileURL, options: [], error: &coordinationError, byAccessor: body
            )
        case .writing:
            coordinator.coordinate(
                writingItemAt: fileURL, options: .forReplacing, error: &coordinationError, byAccessor: body
            )
        }

        if let coordinationError { throw coordinationError }
        // Unreachable: the coordinator either runs the accessor or reports why it did not.
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
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
