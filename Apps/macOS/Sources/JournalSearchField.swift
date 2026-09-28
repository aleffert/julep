import SwiftUI
import AppKit
import Observation

/// The toolbar's search field, and what it asks the editor to do.
///
/// Classic find: typing walks to the first match from where the search started, Return and
/// ⌘G step from the one selected, escape gives the keyboard back to the journal. The editor
/// is what actually finds and selects, so it installs the closures below when it attaches --
/// they are the only thing the field knows about it.
@MainActor @Observable
final class SearchModel {
    enum Step {
        /// Find-as-you-type. From where the search began, never from the last match:
        /// continuing from the selection would walk one match further down the journal for
        /// every letter typed, so a term would arrive somewhere different depending on how
        /// fast it was spelled.
        case fromAnchor(Int)
        case next
        case previous
    }

    private(set) var term = ""

    /// The term is nowhere in the journal. All that is said about that while typing, because
    /// a beep per keystroke is not feedback.
    private(set) var isFailing = false

    /// Where a fresh search counts from. An offset into text the user can edit underneath it,
    /// so it is a hint: `JournalSearch` clamps it rather than trusting it.
    private var anchor: Int?

    /// Selects whatever this step lands on, answering false when the term is nowhere in the
    /// journal.
    var perform: (String, Step) -> Bool = { _, _ in false }
    var caret: () -> Int = { 0 }
    var focusEditor: () -> Void = {}
    /// Installed by the field, because ⌘F arrives at the menu rather than at the field.
    var focusField: () -> Void = {}

    /// ⌘F. Selects what is already in the field, so the next keystroke replaces it and a
    /// repeated ⌘F is a fresh search rather than an append.
    func beginSearch() {
        anchor = caret()
        focusField()
    }

    func termChanged(to newTerm: String) {
        term = newTerm
        guard !newTerm.isEmpty else {
            isFailing = false
            return
        }
        let from = anchor ?? caret()
        anchor = from
        isFailing = !perform(newTerm, .fromAnchor(from))
    }

    func findNext() { step(.next) }
    func findPrevious() { step(.previous) }

    /// Return, ⌘G, ⇧⌘G. Beeps when the term is not there, which is what a Mac has always
    /// done at a search with no answer.
    private func step(_ step: Step) {
        guard !term.isEmpty else { return }
        // An explicit step continues from the selection, so the anchor has done its job.
        anchor = nil
        isFailing = !perform(term, step)
        if isFailing { NSSound.beep() }
    }

    /// Escape. Leaves the match selected -- it is what was being looked for -- and puts the
    /// keyboard back in the journal.
    func cancel() {
        term = ""
        anchor = nil
        isFailing = false
        focusEditor()
    }
}

/// `NSSearchField` rather than SwiftUI's `.searchable`: Return and ⇧Return have to mean next
/// and previous, and the field has to be able to show that a term was not found. Neither is
/// reachable through the search modifier.
struct SearchFieldView: NSViewRepresentable {
    let model: SearchModel
    /// Handed over as values rather than read off the model down in `updateNSView`: it is
    /// reading them in the enclosing view's body that registers the dependency bringing the
    /// update here at all.
    let term: String
    let isFailing: Bool

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Search"
        // Every change is handled through the delegate below, so the field's own action --
        // and the pause it would wait out before sending one -- has nothing left to add.
        field.sendsWholeSearchString = false
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.setAccessibilityIdentifier("nav.search")
        model.focusField = { [weak field] in field?.selectText(nil) }
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.model = model
        // Only when they disagree: assigning the same string back moves the field's insertion
        // point to the end, which on every keystroke is a field that cannot be edited.
        if field.stringValue != term { field.stringValue = term }
        field.textColor = isFailing ? .systemRed : .controlTextColor
    }

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    @MainActor final class Coordinator: NSObject, NSSearchFieldDelegate {
        var model: SearchModel

        init(model: SearchModel) {
            self.model = model
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            model.termChanged(to: field.stringValue)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy selector: Selector
        ) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)),
                 #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)):
                // Shift is read from the event rather than inferred from which of the two
                // selectors arrived: that depends on the key bindings in force, and both of
                // them mean Return.
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                    model.findPrevious()
                } else {
                    model.findNext()
                }
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                model.cancel()
                return true
            default:
                return false
            }
        }
    }
}
