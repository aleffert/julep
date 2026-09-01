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
