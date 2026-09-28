import Foundation

/// Finding a term in the journal, one match at a time.
///
/// One at a time deliberately. A list of every occurrence would be a cache over a document
/// the user is editing underneath it, invalidated by every keystroke; asking for the next
/// match from where you are needs no such thing, so there is nothing here to go stale. What
/// that costs is a match count, which is the only thing that would require reading the whole
/// journal on every keystroke.
///
/// Offsets are UTF-16 and document-wide -- what a caret reports and what a text view selects.
public enum JournalSearch {
    /// Case- and diacritic-insensitive: the journal is written lowercase but not religiously,
    /// and nobody searching their own notes is thinking about which.
    private static let options: NSString.CompareOptions = [
        .caseInsensitive, .diacriticInsensitive,
    ]

    /// The first occurrence starting at or after `location`, wrapping to the top of the
    /// journal when there is none below it. `nil` only when `term` is nowhere in `text`.
    public static func next(from location: Int, of term: String, in text: String) -> NSRange? {
        guard !term.isEmpty else { return nil }
        let full = text as NSString
        let start = min(max(location, 0), full.length)

        let below = full.range(
            of: term,
            options: options,
            range: NSRange(location: start, length: full.length - start)
        )
        if below.location != NSNotFound { return below }

        // Wrapped -- and over the whole journal rather than only the part above `start`.
        // `range(of:range:)` returns only a match lying entirely inside the range it was
        // given, so one straddling `start` belongs to neither half and searching the halves
        // would lose it.
        let wrapped = full.range(of: term, options: options)
        return wrapped.location == NSNotFound ? nil : wrapped
    }

    /// The last occurrence ending at or before `location`, wrapping to the bottom of the
    /// journal when there is none above it. `nil` only when `term` is nowhere in `text`.
    ///
    /// Bounded by where a match *ends* rather than where it starts, because that is the
    /// question `range(of:range:)` answers exactly. Stepping backwards off a selected match
    /// passes that match's start, so the two only differ for two occurrences of the same
    /// term overlapping each other.
    public static func previous(from location: Int, of term: String, in text: String) -> NSRange? {
        guard !term.isEmpty else { return nil }
        let full = text as NSString
        let end = min(max(location, 0), full.length)

        let above = full.range(
            of: term,
            options: options.union(.backwards),
            range: NSRange(location: 0, length: end)
        )
        if above.location != NSNotFound { return above }

        let wrapped = full.range(of: term, options: options.union(.backwards))
        return wrapped.location == NSNotFound ? nil : wrapped
    }
}
