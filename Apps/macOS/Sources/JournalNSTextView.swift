import AppKit
import JulepKit

/// An `NSTextView` that answers the Item menu and knows when to offer a completion.
final class JournalNSTextView: NSTextView {
    var onToggleItem: () -> Void = {}
    /// Called when the caret has been sitting inside an unfinished `@schedule(` or `[` long
    /// enough that offering the list will not collide with typing.
    var onOfferCompletion: () -> Void = {}
    /// Tab was pressed while the picker's ghost was showing.
    var onAcceptGhost: () -> Void = {}

    // MARK: - Menu actions

    /// The menu sends its action to `nil`, meaning "whoever is first responder". A SwiftUI
    /// coordinator is a delegate, not a responder, so an action routed at it lands nowhere and
    /// the menu item silently does nothing. The text view *is* first responder.
    @objc func toggleItem(_ sender: Any?) {
        onToggleItem()
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(toggleItem(_:)) { return isEditable }
        return super.validateUserInterfaceItem(item)
    }

    // MARK: - Ghost text

    /// What the open list would insert. Set by the coordinator as the highlighted row moves.
    var completionGhost: String? {
        didSet { if completionGhost != oldValue { needsDisplay = true } }
    }

    /// The rest of `@schedule(` when it is part-typed. Recomputed by the view itself.
    private var keywordGhost: String? {
        didSet { if keywordGhost != oldValue { needsDisplay = true } }
    }

    /// Shown after the caret, greyed, and not in the document: what Tab would take.
    private var ghost: String? { completionGhost ?? keywordGhost }

    func refreshKeywordGhost() {
        guard let partial = partialKeywordRange else {
            keywordGhost = nil
            return
        }
        let typed = (string as NSString).substring(with: partial)
        keywordGhost = String(ScheduleAnnotation.opening.dropFirst(typed.count))
    }

    override func didChangeText() {
        super.didChangeText()
        refreshKeywordGhost()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawGhost()
    }

    /// Drawn rather than inserted. Inserting it would put text in the document that the user
    /// never typed -- and this document is a file they own, so anything written into it has
    /// to be something they meant.
    private func drawGhost() {
        guard let ghost, !ghost.isEmpty, let font, let window else { return }
        let caret = firstRect(forCharacterRange: selectedRange(), actualRange: nil)
        guard caret != .zero else { return }
        let origin = convert(window.convertFromScreen(caret), from: nil).origin

        (ghost as NSString).draw(
            at: origin,
            withAttributes: [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]
        )
    }

    // MARK: - Completing the keyword

    /// Tab completes a half-typed `@schedule`, opening the annotation ready for its argument.
    ///
    /// Typing the word out is the one part of the annotation the picker never helped with,
    /// and it is the same eleven characters every time.
    override func insertTab(_ sender: Any?) {
        // Whatever the ghost is showing is what Tab takes -- the argument when a picker is
        // open, the rest of the keyword otherwise.
        if let completionGhost, !completionGhost.isEmpty {
            onAcceptGhost()
            return
        }
        guard let partial = partialKeywordRange else {
            super.insertTab(sender)
            return
        }
        let completed = ScheduleAnnotation.opening
        guard shouldChangeText(in: partial, replacementString: completed) else { return }
        textStorage?.replaceCharacters(in: partial, with: completed)
        didChangeText()
        setSelectedRange(NSRange(location: partial.location + completed.utf16.count, length: 0))
        onOfferCompletion()
    }

    /// The range of a partly-typed `@schedule` immediately before the caret, if there is one.
    private var partialKeywordRange: NSRange? {
        let text = string as NSString
        let caret = selectedRange().location
        guard selectedRange().length == 0, caret <= text.length else { return nil }

        let prefix = text.substring(to: caret) as NSString
        let at = prefix.range(of: "@", options: .backwards)
        guard at.location != NSNotFound else { return nil }

        let typed = prefix.substring(from: at.location)
        guard !typed.contains("\n"), !typed.contains(" ") else { return nil }
        // A prefix of the keyword, and not the whole thing already followed by its paren.
        guard ScheduleAnnotation.opening.lowercased().hasPrefix(typed.lowercased()),
              typed.lowercased() != ScheduleAnnotation.opening.lowercased()
        else { return nil }

        return NSRange(location: at.location, length: caret - at.location)
    }

    // MARK: - Offering a completion

    /// What the caret is in the middle of writing, if anything.
    ///
    /// The rule lives in `JulepKit` rather than here, so both shells agree on what counts as
    /// an unfinished construct and a third convention costs one case rather than one more
    /// copy of this.
    var completionContext: CompletionContext? {
        EditorBehavior.completionContext(in: string, at: selectedRange())
    }

    var isCompleting: Bool { completionContext != nil }

    private var offer: Task<Void, Never>?

    /// Offers the list once typing pauses.
    ///
    /// The delay is the point, not an accident. Presenting straight from a change
    /// notification lands between two keystrokes and eats the one after the paren -- `every
    /// week` arrived as `very week`. Every keystroke cancels the pending offer, so it can
    /// only fire once the user has actually stopped.
    func offerCompletionLater() {
        offer?.cancel()
        guard isCompleting else { return }

        offer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled,
                  let self,
                  self.isCompleting,
                  self.window?.firstResponder === self
            else { return }
            self.onOfferCompletion()
        }
    }
}
