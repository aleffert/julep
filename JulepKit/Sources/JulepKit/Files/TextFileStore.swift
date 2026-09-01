import Foundation
import Observation

/// One text file, kept in sync with the view editing it.
///
/// Deliberately has no opinion about the file's *content*: it moves a `String` between the UI
/// and the container. Parsing is a view over that string, never a gate on it, so a journal the
/// grammar cannot fully read still opens and still saves.
@MainActor @Observable
public final class TextFileStore {
    /// The file's text. Assigning schedules a coordinated write.
    public var text: String = "" {
        didSet {
            guard text != oldValue, isLoaded, !isApplyingExternalChange else { return }
            hasUnsavedChanges = true
            scheduleSave()
        }
    }

    public private(set) var isLoaded = false

    /// Bumped whenever `text` is replaced by something *other* than the editor -- a reload
    /// from disk, an accepted fix-it, a roll.
    ///
    /// The editor adopts on a change to this rather than by comparing strings. A comparison
    /// cannot tell a stale echo of the editor's own edit from a genuine outside change, and
    /// guessing wrong overwrites the buffer mid-keystroke: characters vanish and the caret
    /// jumps to the end.
    public private(set) var externalRevision = 0

    /// Whether the last external change was made *by* the app -- a roll, an accepted fix-it --
    /// rather than the file changing underneath it.
    ///
    /// Only the former belongs in the editor's undo stack. A roll the user cannot take back
    /// is a one-way door on their own journal; a change arriving from another device is not
    /// theirs to undo.
    public private(set) var externalChangeIsUndoable = false

    /// Replaces the text from outside the editor, and saves as normal.
    public func replace(with value: String) {
        pendingSource = nil
        externalRevision += 1
        externalChangeIsUndoable = true
        text = value
    }

    /// Called after the text was replaced by a change arriving from outside -- another
    /// device, or another editor. Whoever derives a model from this store has to re-derive
    /// it, and only the store knows the change happened.
    public var onExternalChange: (@MainActor () -> Void)?

    /// Marks the content changed without materializing it.
    ///
    /// The journal is maintained as a `Document`; joining thirty thousand lines back into a
    /// string on every keystroke is exactly the cost the incremental parse exists to remove.
    /// `source` is consulted only when the text is actually needed -- at a save, or a
    /// comparison against disk -- and is expected to capture the edited value rather than
    /// reach back for it, so it cannot go stale.
    ///
    /// The dirty flag is set *now*, though, not at materialization: while the buffer is
    /// ahead of the file, nothing arriving from disk is worth adopting, and a window where
    /// that is not yet recorded is a window where a reload can undo what was just typed.
    public func contentChanged(source: @escaping @MainActor () -> String) {
        guard isLoaded else { return }
        pendingSource = source
        hasUnsavedChanges = true
        scheduleSave()
    }

    /// The text, with any deferred change brought up to date first. Read this rather than
    /// `text` from outside the store.
    public var currentText: String {
        materialize()
        return text
    }

    /// A change announced by `contentChanged` but not yet joined into a string.
    private var pendingSource: (@MainActor () -> String)?

    /// Joins a deferred change into `text`, without rescheduling the save it already caused.
    private func materialize() {
        guard let pendingSource else { return }
        self.pendingSource = nil
        let value = pendingSource()
        guard value != text else { return }
        isApplyingExternalChange = true
        text = value
        isApplyingExternalChange = false
    }

    /// The last write that failed, if any.
    ///
    /// Never swallowed. A save that quietly fails leaves the screen looking correct while the
    /// file falls behind, which is the same class of invisible failure as an unentitled
    /// iCloud container.
    public private(set) var writeError: String?

    private var file: CoordinatedTextFile?
    private var saveTask: Task<Void, Never>?
    private var isApplyingExternalChange = false
    private let saveDebounce: Duration

    public init(saveDebounce: Duration = .milliseconds(400)) {
        self.saveDebounce = saveDebounce
    }

    public func load(from url: URL) async throws {
        let file = CoordinatedTextFile(fileURL: url)
        let loaded = try await Task.detached(priority: .userInitiated) { try file.read() }.value

        self.file = file
        isApplyingExternalChange = true
        text = loaded
        isApplyingExternalChange = false
        isLoaded = true

        file.startObserving { [weak self] in
            Task { @MainActor in await self?.reloadFromDisk() }
        }
    }

    /// Conflicting versions iCloud is holding for this file.
    public func conflictingVersions() -> [ConflictingVersion] {
        file?.conflictingVersions() ?? []
    }

    public func resolveConflicts(_ resolution: ConflictResolution) throws {
        try file?.resolveConflicts(resolution)
    }

    /// Re-reads the file, discarding nothing in memory that was not already saved.
    public func reload() async {
        await reloadFromDisk()
    }

    /// Pulls in a change made by the other device or another editor.
    private func reloadFromDisk() async {
        guard let file, isLoaded else { return }
        materialize()
        guard let disk = try? await Task.detached(priority: .utility, operation: { try file.read() }).value
        else { return }
        guard disk != text else { return }

        // The file presenter also fires for this store's *own* writes. By the time that
        // callback lands, typing has usually moved on -- so the file holds an older version
        // than the buffer, and adopting it would undo whatever was typed while the write was
        // in flight. It looks like text scrambling itself a second or two after a keystroke,
        // which is the save debounce plus file coordination.
        //
        // Two guards, because either alone leaves a gap. Unsaved changes mean the buffer is
        // ahead of the file no matter what it says, so nothing on disk is worth taking.
        // And once everything is saved, an echo is recognised by matching what was written.
        guard !hasUnsavedChanges else { return }
        guard disk != lastWritten else { return }

        // Assigning would otherwise schedule a save of what was just read.
        isApplyingExternalChange = true
        text = disk
        isApplyingExternalChange = false
        externalChangeIsUndoable = false
        externalRevision += 1
        onExternalChange?()
    }

    /// What this store last put on disk, so its own writes can be recognised when the file
    /// presenter reports them back.
    private var lastWritten: String?

    /// Whether the buffer is ahead of the file. While it is, nothing on disk is worth
    /// adopting -- it can only be older.
    private var hasUnsavedChanges = false

    private func scheduleSave() {
        saveTask?.cancel()
        let debounce = saveDebounce
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            self?.startWriting()
        }
    }

    /// Flushes any pending write immediately, and waits for it.
    public func flush() async {
        saveTask?.cancel()
        materialize()
        startWriting()
        await writeTask?.value
    }

    /// The write currently in flight, if any.
    private var writeTask: Task<Void, Never>?

    /// Brings the file up to date with the buffer, one write at a time.
    ///
    /// Serialised deliberately. `saveTask?.cancel()` cannot stop a save that is already past
    /// its debounce and inside the write, so an unserialised version can have two writes in
    /// flight at once -- and the *older* one can land last, putting stale text on disk. The
    /// loop re-reads `text` each pass, so a change made mid-write is picked up by the same
    /// run rather than racing it.
    private func startWriting() {
        materialize()
        guard writeTask == nil, let file, isLoaded else { return }

        writeTask = Task { [weak self] in
            while let self, self.lastWritten != self.text {
                let value = self.text
                // Recorded before the write: the file presenter can report the change while
                // this is still awaiting, and the echo has to be recognisable by then.
                self.lastWritten = value
                do {
                    try await Task.detached(priority: .utility) { try file.write(value) }.value
                    self.writeError = nil
                } catch {
                    self.lastWritten = nil
                    self.writeError = error.localizedDescription
                    break
                }
            }
            guard let self else { return }
            self.hasUnsavedChanges = self.lastWritten != self.text
            self.writeTask = nil
        }
    }
}
