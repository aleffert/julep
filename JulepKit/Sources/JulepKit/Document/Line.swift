import Foundation

/// The label words that open a section. All three sections are optional and their
/// order is not fixed -- the corpus has a block with `next` before `done`.
public enum SectionLabel: String, Equatable, Sendable, CaseIterable {
    case done
    case next

    /// For the app's own prose; `rawValue` is what the file holds. See `Weekday.displayName`.
    public var displayName: String { rawValue.capitalized }
}

/// A parsed `<weekday> M/D/YYYY` header.
///
/// The three date encodings in the journal -- weekday, numeric date, and the `delta`
/// above the block -- are redundant, and the corpus shows them disagreeing regularly.
/// The header stores what was *written*, never a correction; reconciling them is the
/// diagnostics layer's job.
public struct DayHeader: Equatable, Sendable {
    public var weekday: Weekday
    public var month: Int
    public var day: Int
    public var year: Int

    public init(weekday: Weekday, month: Int, day: Int, year: Int) {
        self.weekday = weekday
        self.month = month
        self.day = day
        self.year = year
    }
}

/// A `@schedule(<arg>)` annotation inside an item.
public struct ScheduleAnnotation: Equatable, Sendable {
    /// What starts an annotation. Typing it is what opens the inline picker.
    public static let opening = "@schedule("
    public static let closing = ")"

    /// The text between the parentheses, verbatim.
    public var argument: String
    /// Covers the whole annotation, `@schedule(` through the closing paren.
    public var span: Span

    public init(argument: String, span: Span) {
        self.argument = argument
        self.span = span
    }
}

/// A `[tag]` at the very start of an item's text.
public struct Tag: Equatable, Sendable {
    /// The word inside the brackets. May contain spaces -- the corpus has `[carbon dating]`.
    public var name: String
    /// Covers the brackets as well as the name.
    public var span: Span

    public init(name: String, span: Span) {
        self.name = name
        self.span = span
    }
}

/// A `- ` item.
public struct Item: Equatable, Sendable {
    /// Everything after the `- ` marker, verbatim -- including the tag and annotation.
    /// Item text is arbitrary: it contains URLs, phone numbers, em dashes, and parentheses,
    /// so nothing may be assumed about it.
    public var text: String
    public var tag: Tag?
    public var annotation: ScheduleAnnotation?

    public init(text: String, tag: Tag? = nil, annotation: ScheduleAnnotation? = nil) {
        self.text = text
        self.tag = tag
        self.annotation = annotation
    }

    /// The item without its `@schedule(...)`, which is what moves to the schedule store.
    /// The annotated line itself stays where it was written.
    public var textWithoutAnnotation: String {
        guard let annotation else { return text }
        return text
            .replacingOccurrences(of: "@schedule(\(annotation.argument))", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

/// What a single line was recognized as.
///
/// `unknown` is a classification like any other rather than an error state. That is what
/// makes lenient parsing true by construction: an unrecognized line still round-trips,
/// because every line round-trips.
public enum LineKind: Equatable, Sendable {
    case dayHeader(DayHeader)
    case sectionLabel(SectionLabel)
    case delta(days: Int)
    case item(Item)
    case blank
    case unknown
}

/// One line of the journal: the bytes as written, plus what they were recognized as.
public struct Line: Equatable, Sendable {
    /// The line exactly as it appears in the file, without its newline.
    /// This is the only thing serialization reads, so it is the source of truth.
    ///
    /// Read-only from outside, because `kind` and `utf16Length` were derived from it when the
    /// line was made. Letting it be rewritten in place would let them disagree with it.
    public private(set) var raw: String
    public private(set) var kind: LineKind

    /// `raw`'s length in UTF-16, the unit text views and edit ranges are expressed in.
    ///
    /// Stored beside `kind` because it is the same sort of fact: read off `raw` once, when
    /// the line is made, and true for as long as the line exists. Deriving it per line
    /// instead turns mapping an edit offset onto a line -- which happens on every keystroke
    /// -- into a walk over the journal's characters rather than a sum of integers.
    public let utf16Length: Int

    public init(raw: String, kind: LineKind) {
        self.raw = raw
        self.kind = kind
        self.utf16Length = raw.utf16.count
    }
}
