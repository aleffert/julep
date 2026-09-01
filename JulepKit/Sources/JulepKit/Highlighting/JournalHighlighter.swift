import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Applies highlighting through TextKit 2's paragraph delegate.
///
/// `NSTextContentStorage` asks for paragraphs as it lays them out, so only the visible part of
/// the journal is ever styled -- the cost does not grow with eight months of history behind
/// the scroll. Both platforms use the same class here; only the view host differs.
public final class JournalHighlighter: NSObject, NSTextContentStorageDelegate {
    public var theme: Theme

    public init(theme: Theme) {
        self.theme = theme
    }

    public func textContentStorage(
        _ textContentStorage: NSTextContentStorage,
        textParagraphWith range: NSRange
    ) -> NSTextParagraph? {
        guard let original = textContentStorage.textStorage?.attributedSubstring(from: range)
        else { return nil }

        let styled = NSMutableAttributedString(attributedString: original)
        let full = NSRange(location: 0, length: styled.length)
        styled.setAttributes(theme.baseAttributes, range: full)

        // The paragraph carries its trailing newline; the grammar classifies lines without it.
        var lineText = original.string
        if lineText.hasSuffix("\n") { lineText.removeLast() }

        for highlight in Highlighting.spans(forLine: lineText) {
            let span = NSRange(location: highlight.span.location, length: highlight.span.length)
            guard span.location >= 0, NSMaxRange(span) <= styled.length else { continue }
            styled.addAttributes(theme.attributes(for: highlight.role), range: span)
        }
        return NSTextParagraph(attributedString: styled)
    }
}
