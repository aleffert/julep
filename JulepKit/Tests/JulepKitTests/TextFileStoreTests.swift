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
}
