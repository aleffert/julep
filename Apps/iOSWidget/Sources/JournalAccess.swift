import Foundation
import JulepKit

/// The widget's access to the journal.
///
/// The widget reads the same file the app does, out of the same iCloud container, rather than a
/// summary the app left behind for it. A summary is only ever as fresh as the last time the
/// phone app ran, and this journal is edited on the Mac too.
enum JournalAccess {
    /// What the widget managed to find out. `unavailable` is its own state and never collapses
    /// into an empty list: a widget that shows nothing to do when it simply cannot see the file
    /// is lying about the journal, which is the failure `Container` exists to prevent.
    enum Reading: Equatable, Sendable {
        case glance(Glance)
        case unavailable
    }

    /// Resolving the container blocks, and a widget is a fresh short-lived process every time,
    /// so it pays that cost on every refresh and can never pay it on the main thread. The
    /// coordinated read is the other half: on a file iCloud has evicted it waits for the
    /// download.
    static func read(today: Date = NaturalDates.today()) async -> Reading {
        await Task.detached(priority: .userInitiated) {
            do {
                let text = try journal().read()
                return .glance(Glance.of(document: Document(text), today: today))
            } catch {
                return .unavailable
            }
        }.value
    }

    /// Rolls the journal from the widget's own process.
    ///
    /// The decision is re-made here, inside the coordinated write, against what the file says
    /// rather than what the rendered widget said a while ago: a button on the home screen can be
    /// tapped twice, or tapped after the app has already rolled, and `Roll.apply` only ever
    /// prepends. Checking inside the coordination is what makes a second tap do nothing instead
    /// of writing a duplicate block for the same day.
    static func roll(today: Date = NaturalDates.today()) async throws {
        try await Task.detached(priority: .userInitiated) {
            try journal().update { text in
                let document = Document(text)
                guard Roll.isNeeded(document: document, today: today),
                      let rolled = Roll.roll(document: document, today: today)
                else { return nil }
                return rolled.serialized
            }
        }.value
    }

    /// Moves one item into its block's `done` section, from the widget's own process.
    ///
    /// Reuses the editor's own move rather than rewriting the lines here, so marking something
    /// done from the home screen and from the margin produce the same file.
    static func markDone(lineIndex: Int, text: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            try journal().update { contents in
                let document = Document(contents)
                guard let index = line(matching: text, near: lineIndex, in: document),
                      let updated = document.markingDone(lineIndex: index)
                else { return nil }
                return updated.serialized
            }
        }.value
    }

    /// Which line the tapped item is on *now*.
    ///
    /// The journal stores no item identity -- its text is the identity -- so a tap carries the
    /// line the widget drew and the text it drew there, and the line is believed only while it
    /// still says that. It may not: the widget draws from a timeline that can be minutes old,
    /// and a roll prepends lines above everything.
    ///
    /// Failing that, the item is found by text in the newest block's open section, which is the
    /// only place the widget draws from. Two items with the same text in one block are
    /// indistinguishable by construction, so the first is taken -- the same thing the margin
    /// would do, since the user is pointing at a line rather than naming one.
    private static func line(matching text: String, near lineIndex: Int, in document: Document) -> Int? {
        if document.lines.indices.contains(lineIndex),
           case .item(let item) = document.lines[lineIndex].kind,
           item.text == text {
            return lineIndex
        }
        return document.blocks.first?.openSection?.itemIndices.first { index in
            guard case .item(let item) = document.lines[index].kind else { return false }
            return item.text == text
        }
    }

    /// Never observed: the widget reads once per refresh and the object dies with the call, so it
    /// is not registered as a file presenter and nothing calls back into it.
    private static func journal() throws -> CoordinatedTextFile {
        CoordinatedTextFile(fileURL: try Container.resolve().journalURL)
    }
}
