import Foundation

/// A concrete, reviewable edit. Never applied without acceptance.
///
/// Expressed as a line-range replacement so the same shape covers rewriting one header and
/// reordering a whole block's sections.
public struct Fix: Equatable, Sendable {
    public var range: Range<Int>
    public var replacement: [String]
    /// What accepting this will do, in one line.
    public var summary: String

    public init(range: Range<Int>, replacement: [String], summary: String) {
        self.range = range
        self.replacement = replacement
        self.summary = summary
    }
}

/// Something the app noticed and wants a human to look at.
public struct Diagnostic: Equatable, Sendable {
    /// Which of a header's three date encodings looks wrong.
    public enum DateField: Equatable, Sendable {
        case weekday
        case numericDate
    }

    public enum Kind: Equatable, Sendable {
        /// A line the grammar does not recognize. Preserved exactly; never rewritten.
        case unrecognizedLine
        /// The header's encodings disagree. `suspect` is the outlier, decided by which
        /// field the other two agree against.
        case dateDisagreement(suspect: DateField)
        /// A `delta` contradicts the gap between two headers that are each internally
        /// consistent, leaving the delta as the only thing that can be wrong.
        case deltaDisagreement
        /// Sections are not in the conventional open -> done -> next order.
        case sectionOrder
    }

    public var lineIndex: Int
    public var kind: Kind
    /// The evidence, in the user's terms -- "the weekday and the delta both say 6/16".
    /// Shown with the fix so the app is visibly proposing rather than correcting.
    public var reasoning: String
    /// `nil` when something is worth flagging but the app has no safe correction to offer.
    public var fix: Fix?

    /// A short heading. The `reasoning` is the detail beneath it -- a full sentence makes a
    /// poor title, and on macOS an alert's title is not even exposed as readable text.
    public var title: String {
        switch kind {
        case .unrecognizedLine: "Julep cannot read this line"
        case .dateDisagreement(.numericDate): "This date looks wrong"
        case .dateDisagreement(.weekday): "This weekday looks wrong"
        case .deltaDisagreement: "This gap looks wrong"
        case .sectionOrder: "These sections are out of order"
        }
    }

    public init(lineIndex: Int, kind: Kind, reasoning: String, fix: Fix? = nil) {
        self.lineIndex = lineIndex
        self.kind = kind
        self.reasoning = reasoning
        self.fix = fix
    }
}

extension Document {
    /// Applies a fix. The document is otherwise untouched -- fixes are always a replacement
    /// of a known line range, never a rewrite of the file.
    public func applying(_ fix: Fix) -> Document {
        var updated = lines
        updated.replaceSubrange(
            fix.range,
            with: fix.replacement.map { Line(raw: $0, kind: Grammar.classify($0)) }
        )
        return Document(lines: updated)
    }

    /// Applies several fixes at once.
    ///
    /// Applied from the bottom of the file upward, so an earlier fix that changes the number
    /// of lines cannot invalidate the ranges of the ones below it.
    public func applying(_ fixes: [Fix]) -> Document {
        fixes.sorted { $0.range.lowerBound > $1.range.lowerBound }
            .reduce(self) { $0.applying($1) }
    }
}
