import Foundation

public enum ContainerError: LocalizedError {
    /// The ubiquity container could not be resolved.
    case ubiquityUnavailable(identifier: String)

    public var errorDescription: String? {
        switch self {
        case .ubiquityUnavailable(let identifier):
            "iCloud container \(identifier) is unavailable. Check that the app is signed with "
                + "the iCloud entitlement and that iCloud Drive is enabled for this account."
        }
    }
}

/// Locates the iCloud container the journal lives in.
///
/// Resolution failure is a hard error, never a fall back to local storage. An unentitled or
/// signed-out build otherwise looks completely healthy while writing to a directory the other
/// device will never see -- which is exactly how the entitlement bug during setup stayed
/// invisible behind a green build.
public struct Container: Sendable {
    public static let defaultIdentifier = "iCloud.com.quipsoteric.julep"

    /// The container's `Documents` directory, which is what iCloud Drive exposes to Finder
    /// and the Files app. The journal has to stay openable in any text editor.
    public let documentsURL: URL

    public init(documentsURL: URL) {
        self.documentsURL = documentsURL
    }

    /// Resolves the ubiquity container. Blocking, so it must not run on the main thread --
    /// the first call in a process can take a while.
    public static func iCloud(identifier: String = defaultIdentifier) throws -> Container {
        guard let root = FileManager.default.url(forUbiquityContainerIdentifier: identifier) else {
            throw ContainerError.ubiquityUnavailable(identifier: identifier)
        }
        let documents = root.appending(path: "Documents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        return Container(documentsURL: documents)
    }

    // MARK: - Resolution

    #if DEBUG
    public static let localContainerArgument = "--local-container"
    #endif

    /// The container the app should actually use.
    ///
    /// In debug builds, a `--local-container <path>` launch argument points the app at a plain
    /// directory instead. That keeps a fast simulator loop without signing an Apple ID into the
    /// simulator; the sanctioned alternative is to sign in and use `xcrun simctl icloud_sync`.
    ///
    /// It is deliberately a hole in the fail-hard rule above, so it is kept as small as
    /// possible: opt-in by argument, and compiled out of release entirely. A *missing* iCloud
    /// container always fails hard, in every configuration.
    public static func resolve(
        identifier: String = defaultIdentifier,
        arguments: [String] = CommandLine.arguments
    ) throws -> Container {
        #if DEBUG
        if let local = try localOverride(arguments: arguments) { return local }
        #endif
        return try iCloud(identifier: identifier)
    }

    #if DEBUG
    static func localOverride(arguments: [String]) throws -> Container? {
        guard let flag = arguments.firstIndex(of: localContainerArgument),
              arguments.index(after: flag) < arguments.endIndex
        else { return nil }

        let directory = URL(filePath: arguments[arguments.index(after: flag)])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return Container(documentsURL: directory)
    }
    #endif

    public var journalURL: URL { documentsURL.appending(path: "journal.txt") }
}
