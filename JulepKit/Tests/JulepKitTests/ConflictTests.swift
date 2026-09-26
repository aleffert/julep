import Foundation
import Testing
@testable import JulepKit

@Suite("Conflict handling")
struct ConflictTests {
    /// The joined file must survive the parser untouched, and the marker must be *visible* --
    /// an unreadable line is flagged in the gutter, which is how the user learns both sides
    /// were kept.
    @Test func keepingBothPreservesEverythingAndFlagsTheSeam() {
        let mine = "monday 8/31/2026\n- typed on the mac"
        let theirs = "monday 8/31/2026\n- typed on the phone"
        let joined = CoordinatedTextFile.appending(theirs, to: mine, from: "Spare iPhone")

        // Nothing from either side is lost.
        #expect(joined.contains("- typed on the mac"))
        #expect(joined.contains("- typed on the phone"))

        // And it round-trips, like any other text.
        #expect(Document(joined).serialized == joined)

        // The seam is announced rather than silent.
        let document = Document(joined)
        let diagnostics = Diagnostics.analyze(document)
        #expect(diagnostics.contains { $0.kind == .unrecognizedLine })
        let marker = document.lines.first { $0.kind == .unknown }?.raw
        #expect(marker?.contains("Spare iPhone") == true)
    }

    @Test func anUnnamedDeviceStillProducesAReadableMarker() {
        let joined = CoordinatedTextFile.appending("b", to: "a", from: nil)
        #expect(joined.contains("another device"))
        #expect(Document(joined).serialized == joined)
    }

    /// A file with no conflicts reports none and resolving it is a no-op.
    @Test func aCleanFileHasNoConflicts() throws {
        let directory = URL.temporaryDirectory.appending(path: "julep-conflict-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = CoordinatedTextFile(fileURL: directory.appending(path: "journal.txt"))
        try file.write(Corpus.text)

        #expect(!file.hasConflicts)
        #expect(file.conflictingVersions().isEmpty)
        try file.resolveConflicts(.keepCurrent)
        #expect(try file.read() == Corpus.text)
    }
}

/// The disagreement that is not an iCloud conflict: this device's own file, changed by another
/// local process in the same lines the app had changed.
@Suite("File-on-disk conflicts")
@MainActor
struct FileOnDiskConflictTests {
    private func loadedWorkspace() async throws -> (Workspace, URL) {
        let directory = URL.temporaryDirectory.appending(path: "julep-fod-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "journal.txt")
        try "a\nb\nc".write(to: url, atomically: true, encoding: .utf8)

        let workspace = Workspace(saveDebounce: .milliseconds(10))
        await workspace.load(resolving: { Container(documentsURL: directory) })
        return (workspace, url)
    }

    /// Standing up the disagreement: the buffer and the file changed the same line.
    private func conflicted() async throws -> (Workspace, URL) {
        let (workspace, url) = try await loadedWorkspace()
        workspace.journalText = "a\nMINE\nc"
        try "a\nTHEIRS\nc".write(to: url, atomically: true, encoding: .utf8)
        await workspace.flush()
        return (workspace, url)
    }

    @Test func itIsSurfacedAlongsideTheICloudOnes() async throws {
        let (workspace, _) = try await conflicted()
        #expect(workspace.conflicts.count == 1)
        #expect(workspace.conflicts.first?.source == .fileOnDisk)
        #expect(workspace.conflicts.first?.text == "a\nTHEIRS\nc")
    }

    /// It has no `NSFileVersion` behind it, so it has to be settled by its own route rather
    /// than by the one that marks iCloud versions resolved.
    @Test func keepingThisDevicesVersionWritesItAndClearsTheConflict() async throws {
        let (workspace, url) = try await conflicted()
        await workspace.resolveConflicts(.keepCurrent)
        await workspace.flush()

        #expect(workspace.conflicts.isEmpty)
        #expect(try String(contentsOf: url, encoding: .utf8) == "a\nMINE\nc")
    }

    @Test func takingTheFileAdoptsItAndClearsTheConflict() async throws {
        let (workspace, url) = try await conflicted()
        await workspace.resolveConflicts(.takeOther(id: Workspace.fileOnDiskID))
        await workspace.flush()

        #expect(workspace.conflicts.isEmpty)
        #expect(workspace.journalText == "a\nTHEIRS\nc")
        #expect(try String(contentsOf: url, encoding: .utf8) == "a\nTHEIRS\nc")
        #expect(workspace.document.serialized == "a\nTHEIRS\nc", "the parsed document went stale")
    }

    @Test func keepingBothKeepsEveryLineAndFlagsTheSeam() async throws {
        let (workspace, url) = try await conflicted()
        await workspace.resolveConflicts(.keepBoth(id: Workspace.fileOnDiskID))
        await workspace.flush()

        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written.contains("MINE"))
        #expect(written.contains("THEIRS"))
        #expect(workspace.conflicts.isEmpty)
    }

    /// Overlapping changes are exactly what a merge could not settle, so none is offered.
    @Test func noMergeIsOfferedForWhatAMergeAlreadyRefused() async throws {
        let (workspace, _) = try await conflicted()
        let version = try #require(workspace.conflicts.first)
        #expect(workspace.mergeOffer(for: version) == nil)
    }

    /// And a version that *does* merge is offered as one, rather than made into a choice.
    @Test func aMergeableVersionIsOffered() async throws {
        let (workspace, _) = try await loadedWorkspace()
        let version = ConflictingVersion(
            id: "other", deviceName: "Mac", modified: nil, text: "prepended\na\nb\nc"
        )
        #expect(workspace.mergeOffer(for: version) == "prepended\na\nb\nc")

        workspace.journalText = "a\nb\nC"
        #expect(workspace.mergeOffer(for: version) == "prepended\na\nb\nC")
    }
}
