import Foundation

/// Per-line classification.
///
/// Parsing is context-light: every line is classified on its own, with no state carried
/// between lines. Block and section structure is recovered afterwards as a computed view
/// (see `Document.blocks`), which is what lets sections appear in any order and lets any
/// of them be missing.
///
/// Leading whitespace carries no meaning -- there is no nesting in this format -- so it is
/// ignored for classification and preserved in `Line.raw`.
public enum Grammar {
    // `Regex` is not `Sendable`, but a compiled literal is immutable and these are only
    // ever read. Hoisting them out of `classify` keeps reclassification cheap, which matters
    // because every keystroke reclassifies a line.
    nonisolated(unsafe) private static let dayHeaderPattern =
        #/^(?<weekday>[a-z]+) (?<month>\d{1,2})/(?<day>\d{1,2})/(?<year>\d{4})$/#
    nonisolated(unsafe) private static let deltaPattern = #/^delta (?<days>\d+) days?$/#

    /// The marker that makes a line an item. Two literal characters, never a list widget.
    public static let itemMarker = "- "

    /// A `delta N days` line, written the way `deltaPattern` reads it.
    ///
    /// Beside the pattern that parses it deliberately: the singular `day` is easy to get
    /// wrong in one place and right in another, and a delta the grammar cannot read back is
    /// an unrecognized line in the user's journal.
    public static func deltaLine(days: Int) -> String {
        "delta \(days) day\(days == 1 ? "" : "s")"
    }

    public static func classify(_ raw: String) -> LineKind {
        let content = raw.trimmingCharacters(in: .whitespaces)
        if content.isEmpty { return .blank }

        // Items first: a `- ` prefix is unambiguous, and item text is arbitrary enough
        // that it could otherwise be mistaken for a label or a header.
        if let item = parseItem(raw: raw) { return .item(item) }

        if let label = SectionLabel(rawValue: content) { return .sectionLabel(label) }

        if let match = content.wholeMatch(of: deltaPattern), let days = Int(match.days) {
            return .delta(days: days)
        }

        if let match = content.wholeMatch(of: dayHeaderPattern),
           let weekday = Weekday(rawValue: String(match.weekday)),
           let month = Int(match.month), let day = Int(match.day), let year = Int(match.year) {
            return .dayHeader(DayHeader(weekday: weekday, month: month, day: day, year: year))
        }

        return .unknown
    }

    // MARK: - Items

    private static func parseItem(raw: String) -> Item? {
        // Find the marker past any leading whitespace, keeping the raw offset so spans
        // stay anchored to the line as written.
        var cursor = raw.startIndex
        while cursor < raw.endIndex, raw[cursor] == " " || raw[cursor] == "\t" {
            cursor = raw.index(after: cursor)
        }
        let rest = raw[cursor...]

        let textStart: String.Index
        if rest.hasPrefix(itemMarker) {
            textStart = raw.index(cursor, offsetBy: itemMarker.count)
        } else if rest == "-" {
            // An item emptied out by `item-toggle` or a return on a blank item.
            textStart = raw.endIndex
        } else {
            return nil
        }

        let text = String(raw[textStart...])
        let textOffset = textStart.utf16Offset(in: raw)
        return Item(
            text: text,
            tag: parseTag(text: text, textOffset: textOffset),
            annotation: parseAnnotation(text: text, textOffset: textOffset)
        )
    }

    /// A `[tag]` is only a tag at the very start of the item text. Brackets anywhere else
    /// are ordinary characters.
    private static func parseTag(text: String, textOffset: Int) -> Tag? {
        guard text.first == "[", let close = text.firstIndex(of: "]") else { return nil }
        let name = String(text[text.index(after: text.startIndex)..<close])
        let length = close.utf16Offset(in: text) + 1
        return Tag(name: name, span: Span(location: textOffset, length: length))
    }

    /// Scans `@schedule(...)`, matching parentheses by depth rather than to the first `)`.
    /// Item text contains parenthesized URLs, so a naive scan would truncate the argument.
    private static func parseAnnotation(text: String, textOffset: Int) -> ScheduleAnnotation? {
        guard let opening = text.range(of: ScheduleAnnotation.opening) else { return nil }

        var depth = 1
        var cursor = opening.upperBound
        while cursor < text.endIndex {
            switch text[cursor] {
            case "(": depth += 1
            case ")": depth -= 1
            default: break
            }
            if depth == 0 { break }
            cursor = text.index(after: cursor)
        }
        // An unterminated annotation is not an annotation. The line stays a plain item
        // rather than becoming something the app might act on half-written.
        guard depth == 0 else { return nil }

        let start = opening.lowerBound.utf16Offset(in: text)
        let end = text.index(after: cursor).utf16Offset(in: text)
        return ScheduleAnnotation(
            argument: String(text[opening.upperBound..<cursor]),
            span: Span(location: textOffset + start, length: end - start)
        )
    }
}
