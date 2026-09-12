import UIKit

/// A text view that reports when it has actually laid out.
///
/// The gutter positions its marks from TextKit 2 layout fragment frames, and those are only
/// meaningful once the container has its real size. Reading them at configuration time gives
/// frames computed against the wrong width, which puts every mark beside the wrong line as
/// soon as anything wraps.
final class JournalUITextView: UITextView {
    var onLayout: () -> Void = {}

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout()
    }
}

extension UITextView {
    /// Makes a change to the text and tells the keyboard about it.
    ///
    /// The keyboard keeps its own copy of the words around the caret, and autocorrection is
    /// only ever as good as that copy. A change made here -- a return that starts the next
    /// item, a picked completion, a roll arriving from another device -- is one the keyboard
    /// did not make, and unannounced it goes on composing against the text that used to be
    /// there: after a return, `- unpack` and a freshly typed `recieve` came back as the
    /// single word `unpackrecieve`, and the correction offered was for that.
    func changingText(_ mutate: () -> Void) {
        inputDelegate?.textWillChange(self)
        mutate()
        inputDelegate?.textDidChange(self)
    }

    /// A `UITextRange` for a UTF-16 range.
    ///
    /// `replace(_:withText:)` is the only edit that lands in the undo stack, and it speaks
    /// text positions where everything else in the app speaks offsets.
    func range(_ range: NSRange) -> UITextRange? {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length)
        else { return nil }
        return textRange(from: start, to: end)
    }
}
