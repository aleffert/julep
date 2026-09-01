import Foundation

/// What a run of characters is, for display purposes.
public enum HighlightRole: Equatable, Sendable, CaseIterable {
    case dayHeader
    case sectionLabel
    case delta
    /// The literal `- `. Styled, but never replaced by a bullet -- it stays two characters
    /// of plain text, which is the entire point of the project.
    case itemMarker
    case tag
    case annotation
    /// A line the grammar could not read. Marked so the disagreement between the file and
    /// the app's model is visible before it matters.
    case unrecognized
    /// A phone number, email address or link inside an item. See `Detection`.
    case detectedData
}

public struct HighlightSpan: Equatable, Sendable {
    public var role: HighlightRole
    public var span: Span

    public init(role: HighlightRole, span: Span) {
        self.role = role
        self.span = span
    }
}

/// Computes what to style on a single line.
///
/// Per-line, like the grammar itself, which is what lets highlighting run through TextKit 2's
/// paragraph delegate: only the paragraphs actually being laid out are ever classified, so the
/// cost does not grow with the length of the journal.
public enum Highlighting {
    public static func spans(forLine raw: String) -> [HighlightSpan] {
        spans(forLine: raw, kind: Grammar.classify(raw))
    }

    public static func spans(forLine raw: String, kind: LineKind) -> [HighlightSpan] {
        let content = contentSpan(of: raw)

        switch kind {
        case .dayHeader:
            return [HighlightSpan(role: .dayHeader, span: content)]
        case .sectionLabel:
            return [HighlightSpan(role: .sectionLabel, span: content)]
        case .delta:
            return [HighlightSpan(role: .delta, span: content)]
        case .unknown:
            return [HighlightSpan(role: .unrecognized, span: content)]
        case .blank:
            return []
        case .item(let item):
            var spans: [HighlightSpan] = []
            if let marker = markerSpan(of: raw) {
                spans.append(HighlightSpan(role: .itemMarker, span: marker))
            }
            if let tag = item.tag {
                spans.append(HighlightSpan(role: .tag, span: tag.span))
            }
            if let annotation = item.annotation {
                spans.append(HighlightSpan(role: .annotation, span: annotation.span))
            }
            for detection in detections(inLine: raw, kind: kind) {
                spans.append(HighlightSpan(role: .detectedData, span: detection.span))
            }
            return spans
        }
    }

    /// The line without its leading and trailing whitespace. Indentation carries no meaning,
    /// so styling it would suggest a structure that is not there.
    static func contentSpan(of raw: String) -> Span {
        let utf16 = Array(raw.utf16)
        let whitespace: Set<UInt16> = [0x20, 0x09]
        var start = 0
        while start < utf16.count, whitespace.contains(utf16[start]) { start += 1 }
        var end = utf16.count
        while end > start, whitespace.contains(utf16[end - 1]) { end -= 1 }
        return Span(location: start, length: end - start)
    }

    /// The `- ` itself, so it can be de-emphasized without touching the item's text.
    static func markerSpan(of raw: String) -> Span? {
        let content = contentSpan(of: raw)
        guard content.length > 0 else { return nil }
        let utf16 = Array(raw.utf16)
        guard utf16[content.location] == 0x2D else { return nil }  // "-"
        let hasSpace = content.location + 1 < utf16.count && utf16[content.location + 1] == 0x20
        return Span(location: content.location, length: hasSpace ? 2 : 1)
    }
}
