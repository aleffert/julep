import Foundation
import JulepKit

/// The highlighted row of the open completion list.
///
/// Shared between the popover and the key monitor that drives it. The popover deliberately
/// does *not* take keyboard focus -- if it did, typing a date or a tag by hand would go into
/// the list instead of the line -- so arrow keys are routed to this from outside rather than
/// handled by the view.
///
/// Knows nothing about *what* is being completed. A schedule argument and a tag name differ
/// only in their candidates and their closing delimiter, and both arrive here already
/// decided; see `CompletionKind`.
@MainActor @Observable
final class CompletionModel {
    private(set) var context: CompletionContext
    private(set) var options: [CompletionOption]
    private(set) var highlighted = 0

    init(context: CompletionContext, options: [CompletionOption]) {
        self.context = context
        self.options = options
    }

    /// Keeps the list in step with the line as it is typed.
    func update(context: CompletionContext, options: [CompletionOption]) {
        // Back to the top whenever the filter changes: the row that was highlighted was
        // chosen against a different list.
        if context.typed != self.context.typed || context.kind != self.context.kind {
            highlighted = 0
        }
        self.context = context
        self.options = options
    }

    var selected: CompletionOption? {
        options.indices.contains(highlighted) ? options[highlighted] : nil
    }

    /// What is left to add to reach the highlighted option, given what is already typed.
    ///
    /// The ghost has to absorb the typed prefix or it repeats it back: typing `9` under a
    /// `9/1/2026` option would otherwise read `9` followed by a ghost `9/1/2026`.
    var ghostRemainder: String? {
        guard let selected else { return nil }
        guard selected.insertion.lowercased().hasPrefix(context.typed.lowercased()) else {
            // Matched on the title rather than on what gets written, so there is no shared
            // prefix to continue and a remainder here would be nonsense.
            return nil
        }
        return String(selected.insertion.dropFirst(context.typed.count)) + context.kind.closing
    }

    func moveDown() {
        highlighted = min(highlighted + 1, max(options.count - 1, 0))
    }

    func moveUp() {
        highlighted = max(highlighted - 1, 0)
    }
}
