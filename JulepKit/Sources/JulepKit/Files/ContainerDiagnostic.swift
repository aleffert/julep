import Foundation

/// A launch-time self-check for iCloud availability.
///
/// This exists because the failure it reports was invisible for an entire afternoon during
/// setup: an app whose entitlements have been stripped builds clean, launches clean, and
/// simply never syncs. Making the answer one command away is cheaper than rediscovering it.
public enum ContainerDiagnostic {
    public static let launchArgument = "--container-check"
    /// Prints the schedule store and what the app makes of it, then exits.
    public static let scheduleArgument = "--schedule-check"

    /// Runs the check and exits if asked. Call before any UI.
    public static func runIfRequested(arguments: [String] = CommandLine.arguments) {
        if arguments.contains(scheduleArgument) {
            FileHandle.standardError.write(Data((scheduleReport() + "\n").utf8))
            exit(0)
        }
        guard arguments.contains(launchArgument) else { return }
        FileHandle.standardError.write(Data((report() + "\n").utf8))
        exit(isAvailable ? 0 : 1)
    }

    /// What the journal's annotations add up to.
    ///
    /// There is nothing to cross-check against any more -- the annotations *are* the
    /// schedule -- so this reports what the app reads out of them and what the next roll
    /// would bring forward.
    public static func scheduleReport(identifier: String = Container.defaultIdentifier) -> String {
        guard let container = try? Container.resolve(identifier: identifier),
              let journalText = try? String(contentsOf: container.journalURL, encoding: .utf8)
        else { return "journal: unreadable" }

        let document = Document(journalText)
        let today = NaturalDates.today()
        let upcoming = document.upcomingSchedules(asOf: today)
        let due = Set(document.schedulesDue(asOf: today).map(\.text))

        var lines = [
            "--- deferred (\(upcoming.count)) ---",
            "window since \(document.newestBlockDate.map(NaturalDates.canonical) ?? "(no blocks)")",
        ]
        for (item, when) in upcoming {
            let marker = due.contains(item.text) ? "DUE " : "    "
            let rule = item.rule.map { " (\($0))" } ?? ""
            lines.append("  \(marker)\(item.text)\(rule)  \(NaturalDates.canonical(when))")
        }
        return lines.joined(separator: "\n")
    }

    public static var isAvailable: Bool {
        (try? Container.resolve()) != nil
    }

    public static func report(identifier: String = Container.defaultIdentifier) -> String {
        do {
            let container = try Container.resolve(identifier: identifier)
            let journal = container.journalURL
            let exists = FileManager.default.fileExists(atPath: journal.path(percentEncoded: false))
            return """
            container:  \(identifier)
            documents:  \(container.documentsURL.path(percentEncoded: false))
            journal:    \(journal.lastPathComponent) \(exists ? "(present)" : "(not created yet)")
            status:     available
            """
        } catch {
            return """
            container:  \(identifier)
            status:     UNAVAILABLE
            reason:     \(error.localizedDescription)
            """
        }
    }
}
