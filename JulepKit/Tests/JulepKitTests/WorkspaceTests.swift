import Foundation
import Testing
@testable import JulepKit

@Suite("Workspace")
@MainActor
struct WorkspaceTests {
    private func temporaryContainer() throws -> Container {
        let directory = URL.temporaryDirectory.appending(path: "julep-ws-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return Container(documentsURL: directory)
    }

    @Test func loadingAnEmptyContainerYieldsAnEmptyReadyWorkspace() async throws {
        let container = try temporaryContainer()
        let workspace = Workspace()
        await workspace.load { container }

        #expect(workspace.status == .ready)
        #expect(workspace.journal.text == "")
        #expect(workspace.document.schedules.isEmpty)
    }

    @Test func loadingReadsTheJournal() async throws {
        let container = try temporaryContainer()
        try Corpus.text.write(to: container.journalURL, atomically: true, encoding: .utf8)

        let workspace = Workspace()
        await workspace.load { container }

        #expect(workspace.journal.text == Corpus.text)
        #expect(workspace.document.blocks.count == 52)
    }

    /// The one that matters: what comes back off disk is what the journal held, byte for byte.
    @Test func editsAreWrittenBackLosslessly() async throws {
        let container = try temporaryContainer()
        let workspace = Workspace(saveDebounce: .milliseconds(10))
        await workspace.load { container }

        workspace.journal.text = Corpus.text
        await workspace.flush()

        let onDisk = try String(contentsOf: container.journalURL, encoding: .utf8)
        #expect(onDisk == Corpus.text)
        #expect(Document(onDisk).serialized == Corpus.text)
    }

    // MARK: - Incremental edits

    /// The editor reports edits rather than whole strings, so the path from a keystroke to
    /// the file now runs through a splice. What lands on disk still has to be exactly what
    /// the same edits would have produced by hand.
    @Test func splicedEditsReachDiskUnchanged() async throws {
        let container = try temporaryContainer()
        try Corpus.text.write(to: container.journalURL, atomically: true, encoding: .utf8)
        let workspace = Workspace(saveDebounce: .milliseconds(10))
        await workspace.load { container }

        var expected = Corpus.text as NSString
        for (range, replacement) in [
            (NSRange(location: 0, length: 0), "- typed at the top\n"),
            (NSRange(location: 40, length: 5), ""),
            (NSRange(location: 12, length: 0), "@schedule(9/8/2026)"),
        ] {
            workspace.applyEdit(range: range, replacement: replacement)
            expected = expected.replacingCharacters(in: range, with: replacement) as NSString
        }
        await workspace.flush()

        #expect(workspace.document.serialized == expected as String)
        let onDisk = try String(contentsOf: container.journalURL, encoding: .utf8)
        #expect(onDisk == expected as String)
    }

    /// The join is deferred, but the fact that there is something to join is not. Anything
    /// that needs the text materializes it first, and `currentText` is how outside callers
    /// ask for it.
    @Test func aDeferredEditIsVisibleThroughCurrentText() async throws {
        let container = try temporaryContainer()
        try "- one\n".write(to: container.journalURL, atomically: true, encoding: .utf8)
        let workspace = Workspace(saveDebounce: .seconds(60))
        await workspace.load { container }

        workspace.applyEdit(range: NSRange(location: 6, length: 0), replacement: "- two\n")
        #expect(workspace.document.serialized == "- one\n- two\n")
        #expect(workspace.journalText == "- one\n- two\n")
    }

    /// The dirty flag has to be set when the edit is announced, not when it is joined.
    /// Otherwise a reload landing in between sees a buffer that looks saved and adopts the
    /// older file over it -- which reads as text undoing itself a moment after typing.
    @Test func aReloadDoesNotClobberADeferredEdit() async throws {
        let container = try temporaryContainer()
        try "- one\n".write(to: container.journalURL, atomically: true, encoding: .utf8)
        let workspace = Workspace(saveDebounce: .seconds(60))
        await workspace.load { container }

        workspace.applyEdit(range: NSRange(location: 6, length: 0), replacement: "- two\n")
        await workspace.journal.reload()

        #expect(workspace.document.serialized == "- one\n- two\n")
    }

    /// A change from another device replaces the document wholesale; nothing is spliced onto
    /// a stale one.
    @Test func anOutsideChangeRebuildsTheDocument() async throws {
        let container = try temporaryContainer()
        try "- one\n".write(to: container.journalURL, atomically: true, encoding: .utf8)
        let workspace = Workspace(saveDebounce: .milliseconds(10))
        await workspace.load { container }

        try "monday 9/1/2025\n- from elsewhere\n"
            .write(to: container.journalURL, atomically: true, encoding: .utf8)
        await workspace.journal.reload()

        #expect(workspace.document.serialized == "monday 9/1/2025\n- from elsewhere\n")
        #expect(workspace.document.blocks.count == 1)
    }

    @Test func resyncRebuildsFromTheBufferAndSaves() async throws {
        let container = try temporaryContainer()
        let workspace = Workspace(saveDebounce: .milliseconds(10))
        await workspace.load { container }

        workspace.resyncJournal(from: "- recovered\n")
        await workspace.flush()

        #expect(workspace.document.serialized == "- recovered\n")
        let onDisk = try String(contentsOf: container.journalURL, encoding: .utf8)
        #expect(onDisk == "- recovered\n")
    }

    /// A deferral is a line in the journal, so it is saved by the same write as everything
    /// else. There is no second file to fall out of step with this one.
    @Test func aDeferralIsSavedWithTheJournal() async throws {
        let container = try temporaryContainer()
        let workspace = Workspace(saveDebounce: .milliseconds(10))
        await workspace.load { container }

        workspace.journalText = "monday 8/31/2026\n- renew passport @schedule(9/8/2026)"
        await workspace.flush()

        let onDisk = try String(contentsOf: container.journalURL, encoding: .utf8)
        #expect(Document(onDisk).schedules.map(\.text) == ["renew passport"])
    }

    /// A missing container is a hard failure. It must never quietly fall back to a local
    /// file -- that looks healthy while writing somewhere the other device will never see.
    @Test func anUnavailableContainerFailsLoudlyAndStaysUnready() async throws {
        let workspace = Workspace()
        await workspace.load { throw ContainerError.ubiquityUnavailable(identifier: "iCloud.nope") }

        guard case .failed(let message) = workspace.status else {
            Issue.record("expected failure, got \(workspace.status)"); return
        }
        #expect(message.contains("iCloud.nope"))
    }

    /// A change arriving from the other device must not be echoed straight back as a save.
    @Test func anExternalChangeIsAdoptedWithoutBeingRewritten() async throws {
        let container = try temporaryContainer()
        let workspace = Workspace(saveDebounce: .milliseconds(10))
        await workspace.load { container }

        workspace.journal.text = "monday 8/31/2026\n- a thing"
        await workspace.flush()
        #expect(try String(contentsOf: container.journalURL, encoding: .utf8)
            == "monday 8/31/2026\n- a thing")
    }
}
