import Foundation

/// A version of the file that disagrees with the one on this device.
public struct ConflictingVersion: Identifiable, Sendable {
    public var id: String
    /// Which device wrote it, when iCloud knows.
    public var deviceName: String?
    public var modified: Date?
    public var text: String

    public init(id: String, deviceName: String?, modified: Date?, text: String) {
        self.id = id
        self.deviceName = deviceName
        self.modified = modified
        self.text = text
    }
}

/// A resolution that could not be carried out.
public enum ConflictError: Error, LocalizedError, Equatable {
    /// The chosen version could no longer be read -- iCloud withdrew it, or the resolution
    /// screen is holding an identifier from before a sync. Raised rather than falling back to
    /// keeping this device's copy, because that is a silent discard wearing the costume of a
    /// successful choice.
    case versionUnavailable

    public var errorDescription: String? {
        switch self {
        case .versionUnavailable:
            "That version could not be read. Nothing was changed."
        }
    }
}

/// How a conflict was settled.
public enum ConflictResolution: Equatable, Sendable {
    /// Keep this device's version.
    case keepCurrent
    /// Take the other device's version wholesale.
    case takeOther(id: String)
    /// Keep both, with the loser appended to the file so nothing is dropped.
    case keepBoth(id: String)
}

extension CoordinatedTextFile {
    /// Versions iCloud is holding that disagree with the current file.
    ///
    /// Reported rather than auto-merged. Two devices editing a hand-maintained journal is
    /// rare, but silently discarding one side's edits is unrecoverable, and the file is the
    /// only copy of eight months of history.
    public func conflictingVersions() -> [ConflictingVersion] {
        let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL) ?? []
        return versions.compactMap { version -> ConflictingVersion? in
            guard let text = try? String(contentsOf: version.url, encoding: .utf8) else { return nil }
            return ConflictingVersion(
                id: Self.identifier(of: version),
                deviceName: version.localizedNameOfSavingComputer,
                modified: version.modificationDate,
                text: text
            )
        }
    }

    public var hasConflicts: Bool {
        !(NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL) ?? []).isEmpty
    }

    /// Settles every outstanding conflict.
    ///
    /// `keepBoth` appends the losing version under a marker rather than merging: the app has
    /// no business guessing how two days of a hand-written journal should interleave, and an
    /// unreadable marker line is preserved by the parser and visible in the gutter, so the
    /// user is told rather than surprised.
    public func resolveConflicts(_ resolution: ConflictResolution) throws {
        let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: fileURL) ?? []
        guard !versions.isEmpty else { return }

        switch resolution {
        case .keepCurrent:
            break

        case .takeOther(let id):
            guard let winner = versions.first(where: { Self.identifier(of: $0) == id }),
                  let text = try? String(contentsOf: winner.url, encoding: .utf8)
            else { throw ConflictError.versionUnavailable }
            try write(text)

        case .keepBoth(let id):
            guard let other = versions.first(where: { Self.identifier(of: $0) == id }),
                  let theirs = try? String(contentsOf: other.url, encoding: .utf8)
            else { throw ConflictError.versionUnavailable }
            let mine = try read()
            try write(Self.appending(theirs, to: mine, from: other.localizedNameOfSavingComputer))
        }

        for version in versions { version.isResolved = true }
        try NSFileVersion.removeOtherVersionsOfItem(at: fileURL)
    }

    /// `persistentIdentifier` is `any NSCoding` with no stable string form of its own, so a
    /// description of it stands in as the identity for the length of one resolution.
    static func identifier(of version: NSFileVersion) -> String {
        String(describing: version.persistentIdentifier)
    }

    /// Joins two versions with a marker the parser will preserve and the gutter will flag.
    static func appending(_ theirs: String, to mine: String, from device: String?) -> String {
        let marker = "=== conflicting version from \(device ?? "another device") ==="
        return mine + "\n\n" + marker + "\n" + theirs
    }
}
