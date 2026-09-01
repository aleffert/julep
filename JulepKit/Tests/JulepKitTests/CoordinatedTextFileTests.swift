import Foundation
import Testing
@testable import JulepKit

@Suite("Coordinated file IO")
struct CoordinatedTextFileTests {
    /// Uses a temporary directory rather than the real container: these assert the
    /// coordination and round-trip behavior, which is identical wherever the file lives.
    private func temporaryFile() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: "julep-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "journal.txt")
    }

    @Test func missingFileReadsAsEmpty() throws {
        let file = CoordinatedTextFile(fileURL: try temporaryFile())
        #expect(try file.read() == "")
    }

    @Test func theCorpusSurvivesAWriteReadRoundTrip() throws {
        let file = CoordinatedTextFile(fileURL: try temporaryFile())
        try file.write(Corpus.text)
        #expect(try file.read() == Corpus.text)
    }

    @Test func writingReplacesRatherThanAppends() throws {
        let file = CoordinatedTextFile(fileURL: try temporaryFile())
        try file.write("first")
        try file.write("second")
        #expect(try file.read() == "second")
    }

    @Test func externalChangesAreReported() async throws {
        let url = try temporaryFile()
        let file = CoordinatedTextFile(fileURL: url)
        try file.write("before")

        let notified = SendableBox()
        file.startObserving { notified.signal() }
        defer { file.stopObserving() }

        // Write through a *different* coordinator, standing in for the other device.
        let other = CoordinatedTextFile(fileURL: url)
        try other.write("after")

        #expect(await notified.wait(timeout: .seconds(5)))
        #expect(try file.read() == "after")
    }
}

/// A one-shot signal that a callback fired.
private final class SendableBox: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    func signal() { semaphore.signal() }
    func wait(timeout: DispatchTimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(returning: self.semaphore.wait(timeout: .now() + timeout) == .success)
            }
        }
    }
}
