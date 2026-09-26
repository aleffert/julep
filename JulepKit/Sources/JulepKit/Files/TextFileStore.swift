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
        baseline = loaded

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
        guard disk != baseline else { return }

        // Assigning would otherwise schedule a save of what was just read.
        isApplyingExternalChange = true
        text = disk
        isApplyingExternalChange = false
        externalChangeIsUndoable = false
        baseline = disk
        externalRevision += 1
        onExternalChange?()
    }

    /// The content the buffer and the file are both known to descend from.
    ///
    /// Two jobs, and they are the same value: it recognises this store's own writes when the
    /// file presenter reports them back, and it is the ancestor a three-way merge is taken
    /// against when the file has moved on. That second job is why it is updated wherever the
    /// buffer and the file are known to agree -- after a load and after adopting an outside
    /// change, not only after a write. A stale ancestor does not fail loudly: it produces a
    /// merge that looks clean while undoing the other side's edits.
    ///
    /// `nil` means the file's contents are not known, which is only true after a failed write.
    /// Nothing is merged against an unknown ancestor.
    private var baseline: String?

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
        guard writeTask == nil, let file, isLoaded, mergeConflict == nil else { return }

        writeTask = Task { [weak self] in
            while let self, self.baseline != self.text, self.mergeConflict == nil {
                let value = self.text
                let base = self.baseline
                // Recorded before the write: the file presenter can report the change while
                // this is still awaiting, and the echo has to be recognisable by then.
                // Corrected below on the passes where something other than `value` landed.
                self.baseline = value
                do {
                    let outcome = try await Task.detached(priority: .utility) {
                        try Self.write(value, basedOn: base, to: file)
                    }.value
                    self.writeError = nil
                    switch outcome {
                    case .wrote:
                        break
                    case .merged(let text):
                        self.baseline = text
                        self.adopt(merged: text, mergedFrom: value)
                    case .conflicted(let disk):
                        // The buffer still descends from `base`, so that stays the ancestor.
                        // What is on disk is held for the user to choose against, and nothing
                        // is written until they do.
                        self.baseline = base
                        self.mergeConflict = MergeConflict(onDisk: disk, inBuffer: value)
                    }
                } catch {
                    // What the file now holds is unknown, so nothing is merged against it
                    // until a load or a successful write establishes an ancestor again.
                    self.baseline = nil
                    self.writeError = error.localizedDescription
                    break
                }
            }
            guard let self else { return }
            self.hasUnsavedChanges = self.baseline != self.text
            self.writeTask = nil
        }
    }

    /// One pass of the write, inside a single coordinated access to the file.
    ///
    /// Read-modify-write rather than a blind replace: between this store's last write and this
    /// one, the widget may have rolled the journal from its own process. Coordination alone does
    /// not help there -- it serialises the two writes and the later one still wins wholesale --
    /// and it is not an iCloud conflict either, because both writes are on this device and the
    /// sync engine has no divergence to report. Merging is what keeps both.
    nonisolated private static func write(
        _ value: String,
        basedOn base: String?,
        to file: CoordinatedTextFile
    ) throws -> WriteOutcome {
        var outcome = WriteOutcome.wrote
        try file.update { disk in
            // The file is where this store left it, or its contents are unknown after a failed
            // write. Either way there is nothing trustworthy to merge against.
            guard let base, disk != base else { return value }
            switch TextMerge.merge(base: base, mine: value, theirs: disk) {
            case .merged(let merged):
                outcome = .merged(merged)
                return merged
            case .conflicted:
                outcome = .conflicted(disk)
                return nil
            }
        }
        return outcome
    }

    /// What one pass of the write loop settled.
    private enum WriteOutcome: Sendable {
        /// The file was where this store left it. The buffer is now on disk unchanged.
        case wrote
        /// The file had moved on elsewhere, and both sides' changes were combined into this.
        case merged(String)
        /// The file had moved on in the same lines the buffer changed. Nothing was written.
        case conflicted(String)
    }

    /// Takes a merged file into the buffer.
    ///
    /// The buffer can have moved on while the merge was in flight. Those keystrokes descend
    /// from `value`, which makes `value` their ancestor and combining them the same three-way
    /// merge over again -- rather than an overwrite that would swallow them.
    private func adopt(merged: String, mergedFrom value: String) {
        let adopted: String
        if text == value {
            adopted = merged
        } else {
            switch TextMerge.merge(base: value, mine: text, theirs: merged) {
            case .merged(let combined):
                adopted = combined
            case .conflicted:
                // Typed into the very lines the other side changed, in the moment between the
                // merge and this. There is nothing to take without choosing for them.
                mergeConflict = MergeConflict(onDisk: merged, inBuffer: text)
                baseline = value
                return
            }
        }

        // Not the user's edit, so not theirs to undo -- but the editor still has to place the
        // caret as though the text arrived around it rather than replacing it underneath.
        announce(adopted)
    }

    // MARK: - Merge conflicts

    /// A disagreement between the buffer and the file that a merge could not settle.
    ///
    /// Never resolved by guessing. While one stands, nothing is written: the file keeps what the
    /// other writer put there and the buffer keeps what was typed, so whichever the user picks,
    /// the other was still on disk or on screen until they picked.
    public private(set) var mergeConflict: MergeConflict?

    /// The ancestor a merge would be taken against, for one this store will *offer* rather than
    /// apply. `nil` when the file's contents are not known.
    public var mergeBaseline: String? { baseline }

    public func resolveMergeConflict(_ resolution: MergeConflictResolution) {
        guard let conflict = mergeConflict else { return }
        mergeConflict = nil

        switch resolution {
        case .use(let chosen):
            // Whatever the user picked now descends from what is on disk, so the ordinary write
            // path puts it there and the merge on the way finds nothing left to settle.
            baseline = conflict.onDisk
            if chosen == text {
                hasUnsavedChanges = true
                scheduleSave()
            } else {
                announce(chosen)
            }

        case .takeTheirs:
            announce(conflict.onDisk)
            baseline = conflict.onDisk
            hasUnsavedChanges = false
        }
    }

    /// Puts text into the buffer as a change from outside, so the editor takes it on.
    private func announce(_ value: String) {
        // Assigning would otherwise schedule a save of what was just taken on.
        isApplyingExternalChange = true
        text = value
        isApplyingExternalChange = false
        externalChangeIsUndoable = false
        externalRevision += 1
        onExternalChange?()
    }
}

/// The buffer and the file, when they cannot both be kept.
public struct MergeConflict: Equatable, Sendable {
    /// What another writer -- the widget, another editor -- left in the file.
    public var onDisk: String
    /// What this app has, and has not been able to save.
    public var inBuffer: String

    public init(onDisk: String, inBuffer: String) {
        self.onDisk = onDisk
        self.inBuffer = inBuffer
    }
}

public enum MergeConflictResolution: Equatable, Sendable {
    /// Put this text on the file, over what the other writer left. Keeping what was typed here
    /// is this with the buffer's own text; so is an accepted merge, and so is keeping both.
    case use(String)
    /// Take the file and discard what was typed here.
    case takeTheirs
}
