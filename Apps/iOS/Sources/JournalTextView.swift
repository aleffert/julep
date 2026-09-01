import SwiftUI
import UIKit
import JulepKit

/// Plain text, and nothing but.
///
/// This is the requirement the whole project exists for. Notes turns `- ` into a list widget
/// and fights every line; here `- ` is two literal characters, and autocapitalization -- an
/// active antagonist against a uniformly lowercase journal -- is off.
struct JournalTextView: UIViewRepresentable {
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
    /// Offered by the tag button, and only read when its menu is built -- the journal is
    /// scanned for them then, not on every update.
    var tags: () -> [String]
    /// A diagnostic mark was tapped; the fix is offered, never applied here.
    var onDiagnosticTapped: (Int) -> Void = { _ in }

    func makeUIView(context: Context) -> UITextView {
        let textView = JournalUITextView()
        textView.delegate = context.coordinator
        // The left inset is the gutter: marks live beside the text, not on top of it.
        textView.textContainerInset = UIEdgeInsets(
            top: 12, left: GutterView.width, bottom: 12, right: 8
        )
        textView.alwaysBounceVertical = true
        textView.font = context.coordinator.theme.font
        textView.typingAttributes = context.coordinator.theme.baseAttributes

        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.dataDetectorTypes = []

        (textView.textLayoutManager?.textContentManager as? NSTextContentStorage)?
            .delegate = context.coordinator.highlighter

        context.coordinator.whileAdopting { textView.text = text() }
        context.coordinator.attachToolbar(to: textView)
        context.coordinator.attachGutter(to: textView)
        textView.onLayout = { [weak textView, weak coordinator = context.coordinator] in
            guard let textView, let coordinator else { return }
            coordinator.refreshGutter(textView)
        }
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // The coordinator is made once but the binding is re-created on every update, so it
        // has to be handed over each time; a captured one goes stale.
        context.coordinator.document = document
        context.coordinator.onEdit = onEdit
        context.coordinator.onResync = onResync
        context.coordinator.tags = tags
        context.coordinator.onDiagnosticTapped = onDiagnosticTapped
        // Refreshed after any adoption below; computing marks from text about to be replaced
        // leaves them a revision behind.
        defer { context.coordinator.refreshGutter(textView) }
        // Adopt only on an explicit signal that the text came from elsewhere -- iCloud, a
        // fix-it, a roll. Never by comparing strings: SwiftUI can re-render with a `text`
        // captured before the last keystrokes reached the binding, and a comparison cannot
        // tell that stale echo from a real outside edit. Assigning it back eats characters
        // and throws the caret to the end.
        guard context.coordinator.shouldAdopt(revision: revision) else { return }

        let selection = textView.selectedRange
        // The workspace's document already holds this change -- it is what produced it -- so
        // the buffer must not report it back as an edit to splice on top.
        let text = self.text()
        context.coordinator.isAdopting = true
        defer { context.coordinator.isAdopting = false }
        if revisionIsUndoable {
            // Through the text view's own replace, so it lands in the undo stack. A roll or
            // an accepted fix-it rewrites the journal wholesale, and one the user cannot take
            // back is a one-way door on their own file.
            //
            // Applied as the smallest edit that produces the new text rather than as a
            // whole-buffer replacement, so undo puts back the change rather than selecting
            // the entire journal.
            //
            // One plain edit is now enough. A roll used to write the journal *and* a schedule
            // file, so undo had to reverse both at once and the two were grouped by hand;
            // deferrals live in the journal itself now, so taking back the text takes back
            // all of it.
            if let edit = EditorBehavior.minimalEdit(from: textView.text, to: text),
               let range = textView.range(edit.range) {
                textView.replace(range, withText: edit.replacement)
            }
        } else {
            // Arrived from another device. Not the user's edit, so not theirs to undo.
            textView.text = text
        }

        textView.selectedRange = NSRange(
            location: min(selection.location, (text as NSString).length),
            length: 0
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document, onEdit: onEdit, tags: tags)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let theme = Theme.standard(size: 18, lineSpacing: 7)
        lazy var highlighter = JournalHighlighter(theme: theme)
        var tags: () -> [String]
        var onDiagnosticTapped: (Int) -> Void = { _ in }
        var document: () -> Document
        var onEdit: (NSRange, String) -> Void
        var onResync: (String) -> Void = { _ in }
        private weak var textView: UITextView?
        private let gutter = GutterView(frame: .zero)

        init(
            document: @escaping () -> Document,
            onEdit: @escaping (NSRange, String) -> Void,
            tags: @escaping () -> [String]
        ) {
            self.document = document
            self.onEdit = onEdit
            self.tags = tags
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

        /// Forwards one buffer mutation to the workspace, in the coordinates of the text
        /// before it.
        ///
        /// Driven by the text storage's notification rather than by `shouldChangeTextIn`,
        /// which misses programmatic edits and undo. The storage's *delegate* slot is not
        /// available either: `NSTextContentStorage` holds it, and needs it for layout.
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

        // MARK: - Editing

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText replacement: String
        ) -> Bool {
            // `apply` edits through `replace(_:withText:)`, which reports back through this
            // same callback. Folding an edit that arrived from a fold would re-enter here.
            guard !isApplying else { return true }

            if replacement == "\n" {
                apply(EditorBehavior.newline(in: textView.text, at: range), to: textView)
                return false
            }
            // Closing a `@schedule(...)` rewrites its argument concrete. Folding that into
            // the keystroke keeps it a single undoable edit; rewriting afterwards would leave
            // it as a stray extra step.
            if let folded = EditorBehavior.typing(replacement, in: textView.text, at: range) {
                apply(folded, to: textView)
                return false
            }
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            refreshGutter(textView)
            refreshToolbarButtons()
            refreshCompletions()
        }

        /// Whether an edit made by `apply` is currently in flight. See `shouldChangeTextIn`.
        private var isApplying = false

        /// Applies a targeted replacement rather than rewriting the buffer, so fast typing
        /// cannot outrun the update and lose characters.
        ///
        /// Through `replace(_:withText:)` rather than by mutating the text storage directly.
        /// Only the former registers with the undo manager -- mutating storage behind the
        /// text view's back left every edit made here unundoable, so checking an item off in
        /// the gutter was a one-way door where on the Mac it was not.
        func apply(_ result: EditResult, to textView: UITextView) {
            guard let range = textView.range(result.range) else { return }
            isApplying = true
            textView.replace(range, withText: result.replacement)
            isApplying = false
            textView.selectedRange = result.selection
            refreshGutter(textView)
        }

        /// Adds a Call / Email / Open item to the long-press menu for whatever it opened on.
        ///
        /// Through the edit menu rather than by making the text tappable: the view is
        /// editable, so a plain tap has to keep placing the caret. A long press never
        /// competes with that.
        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            guard let detection = document().detection(atUTF16Offset: range.location) else {
                return nil
            }
            let action = UIAction(title: detection.actionTitle) { _ in
                UIApplication.shared.open(detection.url)
            }
            return UIMenu(children: [action] + suggestedActions)
        }

        // MARK: - Gutter

        func attachGutter(to textView: UITextView) {
            gutter.onTapMark = { [weak self] line in self?.tapped(line: line) }
            textView.addSubview(gutter)

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
            refreshGutter(textView)
        }

        /// Recomputed from the text each time, because the document -- and therefore what is
        /// open, and what the app cannot read -- changes with every keystroke.
        ///
        /// Called from the text view's own layout pass, so fragment frames reflect the real
        /// container width and marks stay beside their line even when it wraps.
        func refreshGutter(_ textView: UITextView) {
            let document = self.document()
            let rows = textView.gutterRows(lineStartOffsets: document.lineStartOffsets)
            // Marks are asked for by line span, not for the journal: the gutter can only
            // draw beside a row it has, so anything else was derived and thrown away.
            let marks = document.gutterMarks(in: GutterRows.lineSpan(of: rows))

            let frame = CGRect(
                x: 0, y: 0, width: GutterView.width,
                height: max(textView.contentSize.height, textView.bounds.height)
            )
            // Laying out the gutter can trigger another layout pass, so only touch it when
            // something actually moved.
            guard gutter.frame != frame || gutter.needsUpdate(marks: marks, rows: rows) else {
                return
            }
            gutter.frame = frame
            gutter.update(marks: marks, rows: rows)
        }

        /// Rows cover only what is on screen, so scrolling has to recompute them.
        /// `UITextViewDelegate` inherits the scroll callbacks, so no second delegate is needed.
        /// The caret can leave a tag without the text changing at all -- an arrow key, a tap
        /// somewhere else -- and the strip has to go with it.
        func textViewDidChangeSelection(_ textView: UITextView) {
            refreshCompletions()
            refreshToolbarButtons()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let textView = scrollView as? UITextView else { return }
            refreshGutter(textView)
        }

        private func tapped(line: Int) {
            guard let textView else { return }
            let document = self.document()
            let marks = document.gutterMarks(in: line..<(line + 1))

            switch marks[line] {
            case .diagnostic:
                // Offered, never applied from the mark itself.
                onDiagnosticTapped(line)
            case .openItem:
                // Confined to the block the item sits in -- `markingDone` moves one line
                // between two sections -- so the edit is that, not a rewrite of the journal.
                guard let updated = document.markingDone(lineIndex: line),
                      let edit = EditorBehavior.minimalEdit(
                          from: textView.text, to: updated.serialized
                      )
                else { return }
                // The tap was in the margin, not in the text. Checking an item off is no
                // reason to move the insertion point, and it used to throw it to the top.
                let caret = min(textView.selectedRange.location, updated.utf16Length)
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

        // MARK: - Accessory toolbar

        /// Above the keyboard rather than buried in a menu: on a phone this is the only place
        /// these actions are cheap enough to actually use.
        func attachToolbar(to textView: UITextView) {
            self.textView = textView
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            // Undo and redo, where the item buttons used to be. Return already continues a
            // list and the gutter already marks things done, so those two were spending the
            // most reachable space on a phone doing what the keyboard and the margin do --
            // whereas undo has no other home here at all.
            let undo = barButton("toolbar.undo", "arrow.uturn.backward") { [weak self] in
                self?.textView?.undoManager?.undo()
            }
            let redo = barButton("toolbar.redo", "arrow.uturn.forward") { [weak self] in
                self?.textView?.undoManager?.redo()
            }
            undoItem = undo
            redoItem = redo
            let tag = barButton("toolbar.tag", "tag") { [weak self] in self?.beginTag() }
            let schedule = barButton("toolbar.schedule", "calendar.badge.clock") { [weak self] in
                self?.beginSchedule()
            }
            tagItem = tag
            scheduleItem = schedule
            toolbar.items = [
                undo,
                redo,
                UIBarButtonItem(systemItem: .flexibleSpace),
                tag,
                schedule,
                UIBarButtonItem(systemItem: .flexibleSpace),
                UIBarButtonItem(
                    image: UIImage(systemName: "keyboard.chevron.compact.down"),
                    primaryAction: UIAction { [weak textView] _ in textView?.resignFirstResponder() }
                ),
            ]
            self.toolbar = toolbar
            textView.inputAccessoryView = toolbar
            refreshToolbarButtons()

            // The one place that sees every undo, however it was asked for -- the toolbar
            // button, a shake, or a hardware keyboard.
            for name in [
                NSNotification.Name.NSUndoManagerDidUndoChange,
                NSNotification.Name.NSUndoManagerDidRedoChange,
            ] {
                NotificationCenter.default.addObserver(
                    forName: name, object: nil, queue: nil
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.afterUndoOrRedo() }
                }
            }
        }

        private var undoItem: UIBarButtonItem?
        private var redoItem: UIBarButtonItem?
        private var tagItem: UIBarButtonItem?
        private var scheduleItem: UIBarButtonItem?
        private var toolbar: UIToolbar?
        private lazy var strip: CompletionStrip = {
            let strip = CompletionStrip()
            strip.onPick = { [weak self] option in self?.accept(option) }
            strip.onPickDate = { [weak self] in self?.beginDateInput() }
            return strip
        }()

        private lazy var dateInput = DateInputView()

        private lazy var dateBar: DateInputBar = {
            let bar = DateInputBar()
            bar.onCancel = { [weak self] in self?.endDateInput() }
            bar.onAccept = { [weak self] in self?.acceptDate() }
            return bar
        }()

        /// Swaps the accessory area between the toolbar and the suggestion strip.
        ///
        /// The strip replaces the toolbar rather than sitting above it: the space over the
        /// keyboard is scarce on a phone, and while a completion is open the four toolbar
        /// actions are not what the user is reaching for.
        ///
        /// Runs on every keystroke and every selection change, which is what keeps the strip
        /// honest -- it appears when the caret enters a completion however it got there, and
        /// leaves when the caret does.
        private func refreshCompletions() {
            guard let textView else { return }
            guard let context = EditorBehavior.completionContext(
                in: textView.text, at: textView.selectedRange
            ) else {
                // Nothing left to complete, so nothing for the calendar to write into either:
                // moving the caret off the annotation puts the keyboard back.
                setInputViews(accessory: toolbar)
                return
            }
            // The calendar owns the input area until it is answered; repopulating the strip
            // underneath it would swap the bar out from under the date being picked.
            guard !isPickingDate else { return }
            strip.update(
                document().completions(for: context),
                offeringDate: context.kind == .scheduleArgument
            )
            setInputViews(accessory: strip)
        }

        /// The one place the input area changes, so a new keyboard and a new bar are adopted
        /// in a single reload rather than two -- reloading twice makes the keyboard visibly
        /// jump on the way from the strip to the calendar.
        ///
        /// `input: nil` is the system keyboard, which is what everything but the calendar
        /// wants back.
        private func setInputViews(accessory: UIView?, input: UIView? = nil) {
            guard let textView else { return }
            guard textView.inputAccessoryView !== accessory || textView.inputView !== input
            else { return }
            textView.inputAccessoryView = accessory
            textView.inputView = input
            textView.reloadInputViews()
        }

        private var isPickingDate: Bool { textView?.inputView === dateInput }

        /// Puts a calendar where the keyboard was, without giving up first responder -- see
        /// `DateInputView` for why that matters.
        private func beginDateInput() {
            dateInput.picker.date = NaturalDates.today()
            dateInput.picker.removeTarget(self, action: nil, for: .valueChanged)
            dateInput.picker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
            dateBar.show(dateInput.argument)
            setInputViews(accessory: dateBar, input: dateInput)
        }

        @objc private func dateChanged() {
            dateBar.show(dateInput.argument)
        }

        /// Puts the keyboard back with the annotation still open, so cancelling costs the
        /// user the tap that opened the calendar and nothing else.
        private func endDateInput() {
            setInputViews(accessory: strip)
            refreshCompletions()
        }

        /// Files the selected day through the same path as a tapped capsule: a date picked
        /// from the grid and one picked from the strip differ only in how they were chosen.
        private func acceptDate() {
            guard let textView,
                  let context = EditorBehavior.completionContext(
                      in: textView.text, at: textView.selectedRange
                  )
            else { return }
            let argument = dateInput.argument
            apply(
                EditorBehavior.accepting(
                    CompletionOption(title: argument, insertion: argument), for: context
                ),
                to: textView
            )
            // The annotation is closed now, so there is no completion left and the keyboard
            // comes back on its own.
            setInputViews(accessory: strip)
            refreshCompletions()
        }

        private func accept(_ option: CompletionOption) {
            guard let textView,
                  let context = EditorBehavior.completionContext(
                      in: textView.text, at: textView.selectedRange
                  )
            else { return }
            apply(EditorBehavior.accepting(option, for: context), to: textView)
            refreshCompletions()
        }

        /// A greyed-out button is the only honest signal that there is nothing to take back.
        ///
        /// The same is true of the other two. A tag and an annotation are things an *item*
        /// carries, so both are refused on a date header or a blank line -- and a button that
        /// silently refuses is indistinguishable from a broken one, which is exactly how they
        /// read with the caret parked off an item.
        private func refreshToolbarButtons() {
            let manager = textView?.undoManager
            undoItem?.isEnabled = manager?.canUndo ?? false
            redoItem?.isEnabled = manager?.canRedo ?? false

            let text = textView?.text ?? ""
            let selection = textView?.selectedRange ?? NSRange(location: 0, length: 0)
            tagItem?.isEnabled = EditorBehavior.openingTag(in: text, at: selection) != nil
            scheduleItem?.isEnabled =
                EditorBehavior.openingSchedule(in: text, at: selection) != nil
        }

        /// Undo and redo move the text without going through the delegate's change callback,
        /// so the things that ride on an edit have to be brought up to date by hand.
        private func afterUndoOrRedo() {
            guard let textView else { return }
            // UIKit selects whatever a text undo put back. Taking back a check-off puts back
            // the whole run of lines the item moved through, which on a phone fills the
            // screen and reads as "everything is selected" -- so it is collapsed to a caret
            // at the change, which is where the insertion point belongs anyway.
            let selection = textView.selectedRange
            if selection.length > 0 {
                textView.selectedRange = NSRange(location: selection.location, length: 0)
            }
            refreshGutter(textView)
            refreshToolbarButtons()
        }

        private func barButton(
            _ identifier: String, _ symbol: String, action: @escaping () -> Void
        ) -> UIBarButtonItem {
            let item = UIBarButtonItem(
                image: UIImage(systemName: symbol),
                primaryAction: UIAction { _ in action() }
            )
            item.accessibilityIdentifier = identifier
            return item
        }

        /// Opens a tag and hands the rest to the suggestion strip.
        ///
        /// A menu of the recent few was the whole affordance before, which meant a tag not in
        /// that handful could only be typed out with its brackets. Writing the `[` and letting
        /// what follows filter reaches every tag in the file, and starting a brand new one is
        /// just typing a name nothing matches.
        private func tagButton() -> UIBarButtonItem {
            barButton("toolbar.tag", "tag") { [weak self] in self?.beginTag() }
        }

        /// Opens a bracket where a tag goes -- the start of the item -- rather than at the
        /// caret, and leaves the caret inside it. Does nothing off an item, since there is
        /// nowhere for a tag to go.
        private func beginTag() {
            guard let textView,
                  let result = EditorBehavior.openingTag(
                      in: textView.text, at: textView.selectedRange
                  )
            else { return }
            apply(result, to: textView)
            refreshCompletions()
        }

        /// Opens an annotation and hands the rest to the suggestion strip, exactly as the
        /// tag button opens a bracket.
        ///
        /// Typing `@schedule(` by hand arrives in the same state, so there is one way to
        /// finish an argument rather than a button that knows a second one.
        private func beginSchedule() {
            guard let textView,
                  let result = EditorBehavior.openingSchedule(
                      in: textView.text, at: textView.selectedRange
                  )
            else { return }
            apply(result, to: textView)
            refreshCompletions()
        }

    }
}
