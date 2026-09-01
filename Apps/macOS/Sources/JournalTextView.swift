import SwiftUI
import AppKit
import JulepKit

/// Plain text, and nothing but. Every automatic substitution AppKit offers is turned off:
/// the journal is uniformly lowercase and `- ` must stay two literal characters.
struct JournalTextView: NSViewRepresentable {
    /// The whole journal as one string. A function rather than a value: it is only wanted
    /// when an outside change actually has to be adopted, and joining the document back
    /// together on every SwiftUI update would undo the point of splicing it.
    var text: () -> String
    /// The journal, parsed. Owned by the workspace and spliced by `onEdit`, so the editor
    /// reads it rather than re-deriving one from the buffer on every keystroke.
    var document: () -> Document
    /// One edit, in the coordinates of the text before it. The workspace splices this into
    /// its document; nothing here writes a whole string back.
    var onEdit: (NSRange, String) -> Void
    /// Rebuilds the workspace's document from the buffer, if the two ever disagree.
    var onResync: (String) -> Void = { _ in }
    /// Increments when `text` was changed by something other than this view.
    var revision: Int
    /// Whether that change was made by the app -- a roll, a fix-it -- and so belongs in undo.
    var revisionIsUndoable: Bool = false
    /// A diagnostic mark was clicked; the fix is offered, never applied here.
    var onDiagnosticClicked: (Int) -> Void = { _ in }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let scrollView = NSScrollView()
        // Explicitly TextKit 2. `init(frame:)` builds a TextKit 1 stack, leaving
        // `textLayoutManager` nil -- which silently disables both the highlighter (it hangs
        // off `NSTextContentStorage`) and the gutter (its rows come from layout fragments).
        // Nothing errors; the features just stop existing.
        let textView = JournalNSTextView(usingTextLayoutManager: true)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude
        )
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true

        textView.onToggleItem = { [weak textView] in
            guard let textView else { return }
            context.coordinator.apply(
                EditorBehavior.toggleItem(in: textView.string, at: textView.selectedRange()),
                to: textView
            )
        }
        textView.onOfferCompletion = { [weak textView] in
            guard let textView else { return }
            context.coordinator.presentCompletion(from: textView)
        }
        textView.onAcceptGhost = { [weak coordinator = context.coordinator] in
            coordinator?.acceptGhost()
        }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        // The gutter is a separate view alongside, so the text only needs breathing room.
        textView.textContainerInset = NSSize(width: 8, height: 12)
        textView.font = context.coordinator.theme.font
        textView.typingAttributes = context.coordinator.theme.baseAttributes

        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        // The schedule list is offered explicitly once typing pauses; automatic completion
        // does not drive a custom `completions(forPartialWordRange:)`.
        textView.isAutomaticTextCompletionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false

        // TextKit 2 styles paragraphs as they are laid out, so only what is on screen is
        // ever classified.
        (textView.textLayoutManager?.textContentManager as? NSTextContentStorage)?
            .delegate = context.coordinator.highlighter

        context.coordinator.whileAdopting { textView.string = text() }

        // The gutter is a *sibling* of the scroll view, not a subview of the text view.
        // `NSTextView` does not publish its subviews to accessibility, so a gutter inside it
        // is invisible to VoiceOver and unclickable by anything driving the app.
        let gutter = context.coordinator.gutter
        container.addSubview(scrollView)
        container.addSubview(gutter)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        gutter.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gutter.topAnchor.constraint(equalTo: container.topAnchor),
            gutter.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            gutter.widthAnchor.constraint(equalToConstant: GutterView.width),
            scrollView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.attach(textView: textView, scrollView: scrollView)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        // The coordinator is made once but the binding is re-created on every update, so it
        // has to be handed over each time. A captured binding goes stale, and a stale one
        // writes into a box nobody reads -- which looks exactly like edits not saving.
        context.coordinator.document = document
        context.coordinator.onEdit = onEdit
        context.coordinator.onResync = onResync
        context.coordinator.onDiagnosticClicked = onDiagnosticClicked
        // The gutter is refreshed *after* any adoption below, not before: computing marks
        // from text that is about to be replaced leaves them a revision behind, so a freshly
        // loaded journal shows no marks at all until something else happens to trigger an
        // update.
        defer { context.coordinator.refreshGutter(textView) }

        // Adopt only on an explicit signal that the text came from elsewhere -- iCloud, a
        // fix-it, a roll. Never by comparing strings: SwiftUI can re-render with a `text`
        // captured before the last keystrokes reached the binding, and a comparison cannot
        // tell that stale echo from a real outside edit. Assigning it back eats characters
        // and throws the caret to the end.
        guard context.coordinator.shouldAdopt(revision: revision) else { return }

        let selection = textView.selectedRange()
        // The workspace's document already holds this change -- it is what produced it -- so
        // the buffer must not report it back as an edit to splice on top.
        let text = self.text()
        context.coordinator.isAdopting = true
        defer { context.coordinator.isAdopting = false }

        if revisionIsUndoable {
            // Routed through the text view's editing machinery so it lands in the undo
            // stack. A roll or an accepted fix-it rewrites the journal wholesale, and one
            // the user cannot take back is a one-way door on their own file.
            //
            // Applied as the smallest edit that produces the new text rather than as a
            // whole-buffer replacement. AppKit selects whatever a text undo puts back, so a
            // whole-buffer one made undoing a roll select the entire journal.
            //
            // One plain edit is now enough. A roll used to write the journal *and* a schedule
            // file, so undo had to reverse both at once and the two were grouped by hand;
            // deferrals live in the journal itself now, so taking back the text takes back
            // all of it.
            if let edit = EditorBehavior.minimalEdit(from: textView.string, to: text) {
                guard textView.shouldChangeText(
                    in: edit.range, replacementString: edit.replacement
                ) else { return }
                textView.textStorage?.replaceCharacters(
                    in: edit.range, with: edit.replacement
                )
                textView.didChangeText()
            }
        } else {
            // Arrived from another device. Not the user's edit, so not theirs to undo.
            textView.string = text
        }

        textView.setSelectedRange(NSRange(
            location: min(selection.location, (text as NSString).length),
            length: 0
        ))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, onEdit: onEdit, onDiagnosticClicked: onDiagnosticClicked)
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate, NSPopoverDelegate {
        let theme = Theme.standard(size: 14, lineSpacing: 4)
        lazy var highlighter = JournalHighlighter(theme: theme)
        var onDiagnosticClicked: (Int) -> Void
        var document: () -> Document
        var onEdit: (NSRange, String) -> Void
        var onResync: (String) -> Void = { _ in }
        let gutter = GutterView()
        private(set) weak var textView: NSTextView?
        private weak var scrollView: NSScrollView?

        init(
            document: @escaping () -> Document,
            onEdit: @escaping (NSRange, String) -> Void,
            onDiagnosticClicked: @escaping (Int) -> Void
        ) {
            self.document = document
            self.onEdit = onEdit
            self.onDiagnosticClicked = onDiagnosticClicked
        }

        /// Whether the buffer is currently being overwritten with text the workspace already
        /// holds. Such a change is not an edit to report back; splicing it onto a document
        /// that already contains it would double the journal.
        var isAdopting = false

        func whileAdopting(_ body: () -> Void) {
            isAdopting = true
            body()
            isAdopting = false
        }

        /// Whether an edit made by `apply` is currently in flight.
        private var isApplying = false

        /// Whether the change being reported is the app's own rather than the user's.
        ///
        /// The two are indistinguishable by the time the text has changed, and some things
        /// should only follow from typing. Offering the schedule picker is one: checking an
        /// item off can leave the caret inside an unclosed `@schedule(` without that being a
        /// request to schedule anything.
        private var isEditingProgrammatically: Bool { isAdopting || isApplying }

        /// Forwards one buffer mutation to the workspace, in the coordinates of the text
        /// before it.
        ///
        /// Driven by the text storage's notification rather than by the delegate callbacks:
        /// `shouldChangeTextIn` misses programmatic edits and undo, and the storage's
        /// *delegate* slot belongs to `NSTextContentStorage`, which needs it for layout.
        /// The notification sees every character change exactly once, whatever caused it.
        private func forwardEdit(from storage: NSTextStorage) {
            guard !isAdopting, storage.editedMask.contains(.editedCharacters) else { return }
            let edited = storage.editedRange
            guard edited.location != NSNotFound else { return }
            let before = NSRange(
                location: edited.location, length: edited.length - storage.changeInLength
            )
            onEdit(before, storage.attributedSubstring(from: edited).string)

            // Cheap enough to run on every keystroke, and the only thing standing between a
            // splice bug and a wrongly written journal. Lengths agreeing does not prove the
            // documents match, but nothing has ever drifted without the length drifting too.
            if document().utf16Length != storage.length { onResync(storage.string) }
        }

        /// The external revision this view has already taken on.
        private var adoptedRevision: Int?

        /// Whether an outside change is waiting. First call always adopts, to pick up the
        /// journal the workspace loaded.
        func shouldAdopt(revision: Int) -> Bool {
            defer { adoptedRevision = revision }
            return adoptedRevision != revision
        }

        /// Moving the caret off the argument -- by clicking, or with the arrow keys when the
        /// picker is closed -- puts it somewhere the list has nothing to say about.
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let journal = notification.object as? JournalNSTextView else { return }
            if !journal.isCompleting { dismissCompletion() }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            refreshGutter(textView)
            guard let journal = textView as? JournalNSTextView else { return }
            // Once the argument is closed, or the caret has moved off it, the list has
            // nothing left to offer.
            if journal.isCompleting {
                refreshCompletionOptions()
                if !isEditingProgrammatically { journal.offerCompletionLater() }
            } else {
                dismissCompletion()
            }
        }

        /// Folds a rewrite into the keystroke that triggers it.
        ///
        /// Closing a `@schedule(...)` rewrites its argument concrete. Doing that here, before
        /// the change, keeps it a single undoable edit; doing it afterwards from
        /// `textDidChange` breaks the text view's typing coalescence and leaves the rewrite as
        /// its own stray undo step.
        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn range: NSRange,
            replacementString: String?
        ) -> Bool {
            guard let replacementString,
                  let folded = EditorBehavior.typing(
                      replacementString, in: textView.string, at: range
                  )
            else { return true }

            apply(folded, to: textView)
            return false
        }

        private func precedingText(in textView: NSTextView) -> String {
            let location = textView.selectedRange().location
            let full = textView.string as NSString
            guard location <= full.length else { return "" }
            return full.substring(to: location)
        }

        // MARK: - Schedule picker

        /// Drops the completion list below the caret when `@schedule(` is typed.
        ///
        /// The text view's own completion UI rather than a popover or a menu. A popover is not
        /// keyboard-navigable without building focus handling by hand, and a menu runs a modal
        /// event loop -- which would take the keyboard away and stop the date being typed out
        /// instead of picked. Completion drops down from the caret, takes arrow keys and
        /// return, dismisses on escape, and keeps every keystroke flowing into the text,
        /// filtering the list as it goes.
        /// The popover currently showing, if any.
        ///
        /// Cleared through `popoverDidClose` rather than only where it is dismissed by hand.
        /// A `.transient` popover closes itself when you click away, and an earlier version
        /// tracked that in a property nothing cleared -- so the picker appeared exactly once
        /// per launch.
        private var picker: NSPopover?

        private var pickerModel: CompletionModel?

        func presentCompletion(from textView: NSTextView) {
            // Already up: leave it where it is rather than tearing it down on every keystroke.
            guard picker?.isShown != true else { return }
            picker?.close()

            guard let clipView = scrollView?.contentView,
                  let caretRect = caretRect(in: textView, relativeTo: clipView)
            else { return }

            guard let journal = textView as? JournalNSTextView,
                  let completionContext = journal.completionContext
            else { return }
            let model = CompletionModel(
                context: completionContext,
                options: document().completions(for: completionContext)
            )
            guard !model.options.isEmpty else { return }
            let popover = NSPopover()
            // Not `.transient`: that closes on *any* key event outside the popover, so the
            // first ⌃n dismissed it and the command then fell straight through to the text
            // view as a caret move. Dismissal is ours to decide -- on escape, on picking, on
            // the annotation closing, and on losing focus.
            popover.behavior = .applicationDefined
            popover.delegate = self
            popover.contentViewController = NSHostingController(
                rootView: CompletionList(model: model) { [weak self, weak textView] option in
                    guard let self, let textView else { return }
                    self.acceptCompletion(option, in: textView)
                    self.dismissCompletion()
                }
            )

            pickerModel = model
            picker = popover
            // Anchored in the *visible* area, not the document. A text view inside a scroll
            // view has a document-sized coordinate space, and a rect from there gets clamped
            // to the view's bounds -- which put the list nowhere near the caret once the
            // journal was long enough to scroll.
            popover.show(relativeTo: caretRect, of: clipView, preferredEdge: .maxY)
            refreshGhost()

            // `.applicationDefined` never closes itself, so losing the window has to.
            focusObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: textView.window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismissCompletion() }
            }
        }

        private var focusObserver: (any NSObjectProtocol)?

        /// The caret's line, in the coordinates of whatever is currently on screen.
        private func caretRect(in textView: NSTextView, relativeTo view: NSView) -> NSRect? {
            guard let window = textView.window else { return nil }
            let screenRect = textView.firstRect(
                forCharacterRange: textView.selectedRange(), actualRange: nil
            )
            var rect = view.convert(window.convertFromScreen(screenRect), from: nil)
            // A caret is zero-width; a popover needs something to hang off.
            if rect.width < 1 { rect.size.width = 1 }
            if rect.height < 1 { rect.size.height = textView.font?.boundingRectForFont.height ?? 16 }
            return rect
        }

        /// Handles the picker's keys while it is open, letting everything else reach the text.
        ///
        /// Routed through commands rather than raw key codes, which is what makes `⌃n`/`⌃p`
        /// work: macOS already binds them to `moveDown:`/`moveUp:`, so arrows and the emacs
        /// bindings arrive here as the same thing.
        ///
        /// The popover takes no focus deliberately. Focusing it would send every keystroke to
        /// the list, so a date could no longer be typed out by hand -- which is exactly what
        /// the list is meant to be an alternative to, not a replacement for.
        private func handlePickerCommand(_ selector: Selector) -> Bool {
            guard picker?.isShown == true else { return false }

            switch selector {
            case #selector(NSResponder.moveDown(_:)),
                 #selector(NSResponder.moveToEndOfParagraph(_:)):
                pickerModel?.moveDown()
                refreshGhost()
            case #selector(NSResponder.moveUp(_:)),
                 #selector(NSResponder.moveToBeginningOfParagraph(_:)):
                pickerModel?.moveUp()
                refreshGhost()
            case #selector(NSResponder.insertNewline(_:)):
                acceptHighlightedSuggestion()
            case #selector(NSResponder.cancelOperation(_:)):
                dismissCompletion()
            default:
                return false
            }
            return true
        }

        /// Shows what is still needed to reach the highlighted row, as ghost text.
        private func refreshGhost() {
            guard let journal = textView as? JournalNSTextView else { return }
            // Absorbs whatever has been typed, so the ghost continues what is being written
            // rather than repeating its beginning back.
            journal.completionGhost = pickerModel?.ghostRemainder
        }

        /// Keeps the list in step with the line as it is typed.
        private func refreshCompletionOptions() {
            guard let journal = textView as? JournalNSTextView, picker?.isShown == true,
                  let context = journal.completionContext
            else { return }
            let document = self.document()
            pickerModel?.update(context: context, options: document.completions(for: context))
            // Nothing left that could finish what is being typed: the list is only noise.
            if pickerModel?.options.isEmpty == true {
                dismissCompletion()
            } else {
                refreshGhost()
            }
        }

        /// Tab, while the picker's ghost is showing.
        func acceptGhost() {
            acceptHighlightedSuggestion()
        }

        private func acceptHighlightedSuggestion() {
            guard let textView, let option = pickerModel?.selected else { return }
            acceptCompletion(option, in: textView)
            dismissCompletion()
        }

        func dismissCompletion() {
            picker?.close()
            picker = nil
            pickerModel = nil
            (textView as? JournalNSTextView)?.completionGhost = nil
            if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
            focusObserver = nil
        }

        func popoverDidClose(_ notification: Notification) {
            picker = nil
            pickerModel = nil
            (textView as? JournalNSTextView)?.completionGhost = nil
            if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
            focusObserver = nil
        }

        /// Finishes what the user opened, with what they picked -- closing paren, closing
        /// bracket, whatever the construct calls for.
        private func acceptCompletion(_ option: CompletionOption, in textView: NSTextView) {
            guard let journal = textView as? JournalNSTextView,
                  let context = journal.completionContext
            else { return }
            apply(EditorBehavior.accepting(option, for: context), to: textView)
        }

        // MARK: - Gutter

        func attach(textView: NSTextView, scrollView: NSScrollView) {
            self.textView = textView
            self.scrollView = scrollView
            gutter.onClickMark = { [weak self] line in self?.clicked(line: line) }

            // Posted synchronously on the main thread, so the edit is forwarded before
            // anything else can observe a buffer the workspace has not been told about.
            NotificationCenter.default.addObserver(
                forName: NSTextStorage.didProcessEditingNotification,
                object: textView.textStorage,
                queue: nil
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let storage = self.textView?.textStorage else { return }
                    self.forwardEdit(from: storage)
                }
            }

            // Rows cover the visible span, so they have to be recomputed once there *is*
            // one. The text view's frame changes when it is first laid out into the scroll
            // view and whenever the window resizes, which is exactly when the visible span
            // becomes known or moves.
            textView.postsFrameChangedNotifications = true
            NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: textView,
                queue: nil
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let textView = self.textView else { return }
                    self.refreshGutter(textView)
                }
            }

            // Rows are computed in the text view's coordinates, so the gutter has to be told
            // how far the text has scrolled beneath it.
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let textView = self.textView else { return }
                    // Rows now cover only what is on screen, so scrolling has to recompute
                    // them, not just slide the ones already there.
                    self.syncGutterScroll()
                    self.refreshGutter(textView)
                }
            }
            refreshGutter(textView)
        }

        private func syncGutterScroll() {
            guard let scrollView else { return }
            gutter.scrollOffset = scrollView.contentView.bounds.origin.y
        }

        func refreshGutter(_ textView: NSTextView) {
            let document = self.document()
            let rows = textView.gutterRows(lineStartOffsets: document.lineStartOffsets)
            // Marks are asked for by line span, not for the journal: the gutter can only
            // draw beside a row it has, so anything else was derived and thrown away.
            let marks = document.gutterMarks(in: GutterRows.lineSpan(of: rows))
            guard gutter.needsUpdate(marks: marks, rows: rows) else { return }
            gutter.update(marks: marks, rows: rows)
            syncGutterScroll()
        }

        private func clicked(line: Int) {
            guard let textView else { return }
            let document = self.document()
            let marks = document.gutterMarks(in: line..<(line + 1))

            switch marks[line] {
            case .diagnostic:
                onDiagnosticClicked(line)
            case .openItem:
                // Confined to the block the item sits in -- `markingDone` moves one line
                // between two sections -- so the edit is that, not a rewrite of the journal.
                // A whole-document undo unit is what made taking this back select every line.
                guard let updated = document.markingDone(lineIndex: line),
                      let edit = EditorBehavior.minimalEdit(
                          from: textView.string, to: updated.serialized
                      )
                else { return }
                // The click was in the margin, not in the text. Checking an item off is no
                // reason to move the insertion point, and it used to throw it to the top.
                let caret = min(textView.selectedRange().location, updated.utf16Length)
                apply(
                    EditResult(
                        range: edit.range,
                        replacement: edit.replacement,
                        selection: NSRange(location: caret, length: 0)
                    ),
                    to: textView
                )
            case nil:
                break
            }
        }

        /// Adds a Call / Email / Open item for whatever was right-clicked.
        ///
        /// Through the context menu rather than by making the text clickable: the view is
        /// editable, so a plain click has to keep placing the caret. A menu never competes
        /// with that.
        func textView(
            _ view: NSTextView,
            menu: NSMenu,
            for event: NSEvent,
            at charIndex: Int
        ) -> NSMenu? {
            guard let detection = document().detection(atUTF16Offset: charIndex) else {
                return menu
            }
            let item = NSMenuItem(
                title: detection.actionTitle,
                action: #selector(openDetected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = detection.url
            menu.insertItem(item, at: 0)
            menu.insertItem(.separator(), at: 1)
            return menu
        }

        @objc private func openDetected(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            NSWorkspace.shared.open(url)
        }

        func textView(
            _ textView: NSTextView,
            doCommandBy selector: Selector
        ) -> Bool {
            // The picker gets first refusal while it is open, so return accepts a suggestion
            // rather than starting a new item.
            if handlePickerCommand(selector) { return true }

            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                apply(EditorBehavior.newline(in: textView.string, at: textView.selectedRange()),
                      to: textView)
                return true
            default:
                return false
            }
        }

        /// Applies a targeted replacement through the text view's own editing machinery, so
        /// undo keeps working and fast typing cannot race a whole-buffer rewrite.
        func apply(_ result: EditResult, to textView: NSTextView) {
            guard textView.shouldChangeText(in: result.range,
                                            replacementString: result.replacement)
            else { return }
            isApplying = true
            textView.textStorage?.replaceCharacters(in: result.range, with: result.replacement)
            textView.didChangeText()
            isApplying = false
            textView.setSelectedRange(result.selection)
            refreshGutter(textView)
        }


    }
}
