import Foundation
import Testing
@testable import JulepKit

@Suite("Text file store")
@MainActor
struct TextFileStoreTests {
    private func temporaryFile() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: "julep-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "journal.txt")
    }

    /// The file presenter reports this store's *own* writes. By the time that lands, typing
    /// has usually moved on -- so the file is older than the buffer, and adopting it would
    /// undo what was typed while the write was in flight.
    ///
    /// Reported as text scrambling itself a second or two after a keystroke, which is the
    /// save debounce plus file coordination.
    @Test func anEchoOfOurOwnWriteIsNotAdopted() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        store.text = "first"
        await store.flush()

        // Typing carries on while the write's notification is still in flight.
        store.text = "first and more"

        // The presenter now reports the file this store just wrote.
        await store.reload()

        #expect(store.text == "first and more", "a stale echo of our own write was adopted")
    }

    /// And the echo must not look like an outside change either, or the editor would take it
    /// on and overwrite the buffer.
    @Test func anEchoDoesNotCountAsAnExternalChange() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        store.text = "first"
        await store.flush()
        let revision = store.externalRevision

        store.text = "first and more"
        await store.reload()

        #expect(store.externalRevision == revision)
    }

    /// A real change from elsewhere is still adopted, and still announced.
    @Test func aGenuineOutsideChangeIsAdopted() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        store.text = "mine"
        await store.flush()
        let revision = store.externalRevision

        try "theirs".write(to: url, atomically: true, encoding: .utf8)
        await store.reload()

        #expect(store.text == "theirs")
        #expect(store.externalRevision > revision, "the editor was never told to take it on")
    }

    /// Replacing from outside the editor announces itself, so the editor adopts it.
    @Test func replacingAnnouncesItself() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        let revision = store.externalRevision
        store.replace(with: "from a roll")
        #expect(store.externalRevision > revision)
        #expect(store.text == "from a roll")

        // And it is still saved, unlike a reload.
        await store.flush()
        #expect(try String(contentsOf: url, encoding: .utf8) == "from a roll")
    }

    /// Ordinary typing must not announce itself, or the editor would clobber its own buffer.
    @Test func typingDoesNotAnnounceItself() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        let revision = store.externalRevision
        store.text = "typed"
        #expect(store.externalRevision == revision)
    }

    // MARK: - Merging

    /// The case the widget creates: another process rolls the journal while this one holds
    /// unsaved edits elsewhere in the file. Coordination alone would serialise the two writes
    /// and let the later one win wholesale, and iCloud reports no conflict because both writes
    /// are on this device.
    @Test func aWriteMergesWithAChangeMadeElsewhere() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        store.text = "header\n- one\n- two"
        await store.flush()

        // This buffer edits the last line...
        store.text = "header\n- one\n- two edited"
        // ...while the widget prepends a block to the file.
        try "rolled\n\nheader\n- one\n- two".write(to: url, atomically: true, encoding: .utf8)

        await store.flush()

        let expected = "rolled\n\nheader\n- one\n- two edited"
        #expect(try String(contentsOf: url, encoding: .utf8) == expected, "the other write was overwritten")
        #expect(store.text == expected, "the merge never reached the buffer")
        #expect(store.mergeConflict == nil)
    }

    /// The merged file has to reach the editor, or the buffer silently disagrees with disk and
    /// the next keystroke writes the other side's change back out.
    @Test func aMergeIsAnnouncedToTheEditor() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        store.text = "a\nb\nc"
        await store.flush()
        let revision = store.externalRevision

        store.text = "a\nb\nC"
        try "prepended\na\nb\nc".write(to: url, atomically: true, encoding: .utf8)
        await store.flush()

        #expect(store.externalRevision > revision)
        #expect(store.externalChangeIsUndoable == false, "a merge is not the user's edit to undo")
    }

    /// Both sides changed the same line. Nothing is written and nothing is chosen.
    @Test func overlappingChangesRaiseAConflictAndWriteNothing() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        store.text = "a\nb\nc"
        await store.flush()

        store.text = "a\nMINE\nc"
        try "a\nTHEIRS\nc".write(to: url, atomically: true, encoding: .utf8)
        await store.flush()

        #expect(store.mergeConflict?.inBuffer == "a\nMINE\nc")
        #expect(store.mergeConflict?.onDisk == "a\nTHEIRS\nc")
        #expect(try String(contentsOf: url, encoding: .utf8) == "a\nTHEIRS\nc", "the other side was overwritten")
        #expect(store.text == "a\nMINE\nc", "what was typed was discarded")
    }

    @Test func keepingMineWritesOverTheOtherVersion() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        store.text = "a\nb"
        await store.flush()
        store.text = "a\nMINE"
        try "a\nTHEIRS".write(to: url, atomically: true, encoding: .utf8)
        await store.flush()
        #expect(store.mergeConflict != nil)

        store.resolveMergeConflict(.use(store.text))
        await store.flush()

        #expect(store.mergeConflict == nil)
        #expect(try String(contentsOf: url, encoding: .utf8) == "a\nMINE")
    }

    @Test func takingTheirsAdoptsTheFileAndStopsWriting() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        store.text = "a\nb"
        await store.flush()
        store.text = "a\nMINE"
        try "a\nTHEIRS".write(to: url, atomically: true, encoding: .utf8)
        await store.flush()

        let revision = store.externalRevision
        store.resolveMergeConflict(.takeTheirs)
        await store.flush()

        #expect(store.mergeConflict == nil)
        #expect(store.text == "a\nTHEIRS")
        #expect(store.externalRevision > revision, "the editor was never told to take it on")
        #expect(try String(contentsOf: url, encoding: .utf8) == "a\nTHEIRS")
    }

    /// The ancestor has to be established at load, not at the first write, or the first save of
    /// a session overwrites whatever arrived while the app was closed.
    @Test func theFirstWriteOfASessionStillMerges() async throws {
        let url = try temporaryFile()
        try "a\nb\nc".write(to: url, atomically: true, encoding: .utf8)

        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        store.text = "a\nb\nC"
        try "prepended\na\nb\nc".write(to: url, atomically: true, encoding: .utf8)
        await store.flush()

        #expect(try String(contentsOf: url, encoding: .utf8) == "prepended\na\nb\nC")
    }

    /// Adopting an outside change moves the ancestor with it. Left behind, the *next* write
    /// merges against a version neither side has any more and quietly undoes the change that
    /// was just taken on.
    @Test func adoptingAnOutsideChangeMovesTheAncestor() async throws {
        let url = try temporaryFile()
        let store = TextFileStore(saveDebounce: .milliseconds(10))
        try await store.load(from: url)

        store.text = "a\nb"
        await store.flush()

        try "prepended\na\nb".write(to: url, atomically: true, encoding: .utf8)
        await store.reload()
        #expect(store.text == "prepended\na\nb")

        store.text = "prepended\na\nB"
        await store.flush()

        #expect(try String(contentsOf: url, encoding: .utf8) == "prepended\na\nB")
        #expect(store.mergeConflict == nil)
    }
}
