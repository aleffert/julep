import Foundation
import Observation

/// The one file the app owns.
///
/// There used to be a schedule file beside it. Deferrals are read out of the journal's own
/// `@schedule(...)` annotations now, which removed not just the file but everything that
/// existed to keep two files in step -- a second store to load, flush and resolve conflicts
/// for, and an undo that had to reverse both halves of a roll at once.
@MainActor @Observable
public final class Workspace {
    public enum Status: Equatable {
        case loading
        case ready
        /// Loading failed. Surfaced prominently and never silently downgraded to a local
        /// file: a store that quietly writes somewhere else looks healthy while losing data.
        case failed(String)
    }

    public private(set) var status: Status = .loading
    public let journal: TextFileStore

    public init(saveDebounce: Duration = .milliseconds(400)) {
        journal = TextFileStore(saveDebounce: saveDebounce)
    }

    /// A save that failed. Surfaced so the screen cannot look correct while the file
    /// silently falls behind.
    public var writeError: String? { journal.writeError }

    /// The journal's text. Forwarded so views can bind straight to it -- `journal` itself is
    /// constant, and a binding cannot be formed through a `let`.
    ///
    /// Read only where a whole string is genuinely wanted: adopting an outside change into
    /// the editor, or handing a diagnostic its context. Per-keystroke work goes through
    /// `applyEdit` instead, which never joins the document back together.
    public var journalText: String {
        get { journal.currentText }
        set {
            journal.text = newValue
            document = Document(newValue)
        }
    }

    /// The journal, parsed.
    ///
    /// The source of truth while editing, not a cache: it holds every line's bytes verbatim,
    /// so `serialized` reproduces the file exactly and there is nothing above it that could
    /// go stale. Edits splice it in place (see `Document.replaceCharacters`), which is what
    /// keeps a keystroke's cost proportional to the lines it touched rather than to the
    /// length of the journal.
    public private(set) var document = Document("")

    /// Applies one editor edit, in the coordinates of the text before it.
    ///
    /// The text file store is told the content changed but not what it now says; the join
    /// happens when the file is actually written.
    public func applyEdit(range: NSRange, replacement: String) {
        document.replaceCharacters(in: range, with: replacement)
        journal.contentChanged(source: { [document] in document.serialized })
    }

    /// Rebuilds the document from a buffer the editor knows to be authoritative.
    ///
    /// A splice and the text storage it mirrors cannot disagree unless a change went
    /// unreported -- but "cannot" is not worth betting someone's journal on, so the editor
    /// checks and calls this if they ever do. Recovering costs one full parse; not
    /// recovering costs the wrong bytes on disk.
    public func resyncJournal(from text: String) {
        document = Document(text)
        journal.contentChanged(source: { [document] in document.serialized })
    }

    /// Rebuilds the document from the store, for a change that did not come through
    /// `applyEdit` -- a reload from disk, or a resolved conflict.
    private func adoptExternalJournal() {
        document = Document(journal.currentText)
    }

    /// Changes to the journal made from outside the editor. See
    /// `TextFileStore.externalRevision`.
    public var journalRevision: Int { journal.externalRevision }

    /// Whether the pending journal change is one the editor should let the user undo.
    public var journalChangeIsUndoable: Bool { journal.externalChangeIsUndoable }

    /// Replaces the journal from outside the editor -- an accepted fix-it, a roll, a reload.
    /// The editor watches `journalRevision` to know it should take this on.
    public func replaceJournal(with value: String) {
        journal.replace(with: value)
        document = Document(value)
    }

    /// Brings everything still open forward onto today. One action: the editor is where
    /// pruning happens.
    ///
    /// Does nothing when there is nothing to bring forward, so a shell can offer this
    /// unconditionally rather than deciding for itself whether a roll would be a no-op. That
    /// includes a day already rolled: `Roll.apply` only ever prepends, so rolling twice used to
    /// write a second block with the same header rather than doing nothing.
    public func roll(today: Date = NaturalDates.today()) {
        guard Roll.isNeeded(document: document, today: today),
              let rolled = Roll.roll(document: document, today: today)
        else { return }
        replaceJournal(with: rolled.serialized)
    }

    public func load(containerIdentifier: String = Container.defaultIdentifier) async {
        await load { try Container.resolve(identifier: containerIdentifier) }
    }

    /// Loads from an explicitly provided container. The resolver runs off the main actor, and
    /// is the seam tests use to point the workspace at a temporary directory.
    public func load(resolving container: @escaping @Sendable () throws -> Container) async {
        status = .loading
        do {
            let container = try await Task.detached(priority: .userInitiated) {
                try container()
            }.value
            try await journal.load(from: container.journalURL)
            adoptExternalJournal()
            journal.onExternalChange = { [weak self] in self?.adoptExternalJournal() }
            status = .ready
            checkForConflicts()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    public func flush() async {
        await journal.flush()
    }

    /// Re-reads the file, in case it changed while the app was not listening.
    ///
    /// The file presenter only reports changes to a running process, and the widget rolls the
    /// journal from its own process while this one is suspended. Without a read on the way back
    /// in, the app carries on from a buffer that is quietly older than the file and writes over
    /// the roll. Discards nothing unsaved: see `TextFileStore.reloadFromDisk`.
    public func reload() async {
        await journal.reload()
    }

    // MARK: - Conflicts

    /// Versions of the journal that disagree with this device's, from either direction: ones
    /// iCloud is holding from another device, and the file itself when something local changed
    /// it in the same lines this app did.
    ///
    /// What a three-way merge could settle has already been settled by the time anything
    /// reaches here. These are the disagreements that are genuinely a choice, and the app does
    /// not make them.
    public var conflicts: [ConflictingVersion] {
        guard let merge = journal.mergeConflict else { return iCloudConflicts }
        return iCloudConflicts + [ConflictingVersion(
            id: Self.fileOnDiskID,
            deviceName: nil,
            modified: nil,
            text: merge.onDisk,
            source: .fileOnDisk
        )]
    }

    /// The identifier the file-on-disk disagreement travels under. It has no `NSFileVersion`
    /// behind it, so it needs a name of its own to be routed by.
    static let fileOnDiskID = "file-on-disk"

    /// Held rather than computed: reading them asks the file system what iCloud is holding,
    /// which is not a question to ask on every redraw. Re-derived after every resolution.
    private var iCloudConflicts: [ConflictingVersion] = []

    public func checkForConflicts() {
        iCloudConflicts = journal.conflictingVersions()
    }

    /// What merging a disagreeing version into this device's would produce, or `nil` when the
    /// two cannot be merged without choosing between them.
    ///
    /// Offered, never applied unattended. For a version from another device the ancestor is a
    /// reasonable assumption rather than a fact -- iCloud does not say what they branched from
    /// -- so acceptance is what makes it safe. See `TextMerge`.
    public func mergeOffer(for version: ConflictingVersion) -> String? {
        guard let base = journal.mergeBaseline else { return nil }
        switch TextMerge.merge(base: base, mine: journalText, theirs: version.text) {
        case .merged(let text):
            return text
        case .conflicted:
            return nil
        }
    }

    /// Settles the outstanding conflicts, then re-reads what iCloud still holds.
    ///
    /// The re-read is the whole point: the list is derived from disk rather than cleared by
    /// hand, so a resolution that only half-succeeded leaves the conflict standing and the
    /// screen stays up. Clearing it here instead would close the screen over a version that
    /// was never actually settled, which is the one outcome this whole path exists to avoid.
    public func resolveConflicts(_ resolution: ConflictResolution) async {
        if let merge = journal.mergeConflict,
           resolution.id == nil || resolution.id == Self.fileOnDiskID {
            resolveFileOnDisk(resolution, merge: merge)
            // `keepCurrent` names no particular disagreement because it answers all of them, so
            // iCloud's are still to settle below. Anything else named this one and is done.
            guard resolution.id == nil else { return }
        }

        // Anything still sitting in the save debounce has to reach the file first. `keepBoth`
        // merges against what is *on disk* while the comparison the user just read was drawn
        // from the buffer, so an unflushed edit would be shown as at stake and then dropped.
        await journal.flush()
        do {
            try journal.resolveConflicts(resolution)
            await journal.reload()
            adoptExternalJournal()
        } catch {
            status = .failed(error.localizedDescription)
        }
        checkForConflicts()
    }

    /// Settles a disagreement with this device's own file.
    ///
    /// Nothing to flush and no `NSFileVersion` to mark resolved: the buffer has been held back
    /// from the file all along, so settling it is choosing what the next ordinary write puts
    /// there. The document is re-derived because the buffer may have just changed under it.
    private func resolveFileOnDisk(_ resolution: ConflictResolution, merge: MergeConflict) {
        switch resolution {
        case .keepCurrent:
            journal.resolveMergeConflict(.use(merge.inBuffer))
        case .takeOther:
            journal.resolveMergeConflict(.takeTheirs)
        case .keepBoth:
            journal.resolveMergeConflict(.use(CoordinatedTextFile.appending(
                merge.onDisk, to: merge.inBuffer, from: nil
            )))
        case .merge(_, let text):
            journal.resolveMergeConflict(.use(text))
        }
        adoptExternalJournal()
    }
}

extension ConflictResolution {
    /// Which disagreement this settles. `keepCurrent` names none, because keeping this
    /// device's version answers every one of them at once.
    var id: String? {
        switch self {
        case .keepCurrent: nil
        case .takeOther(let id): id
        case .keepBoth(let id): id
        case .merge(let id, _): id
        }
    }
}
