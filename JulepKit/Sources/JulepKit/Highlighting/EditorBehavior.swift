import Foundation

/// A single, targeted edit: replace `range` with `replacement`, then put the caret at
/// `selection`.
///
/// Deliberately a *range* replacement rather than a whole new string. Rewriting the entire
/// buffer on every return loses characters when typing outruns the update, and it discards
/// the text view's undo granularity along the way.
public struct EditResult: Equatable, Sendable {
    /// The range in the text this was computed from.
    public var range: NSRange
    public var replacement: String
    /// Where the caret ends up, in the resulting text.
    public var selection: NSRange

    public init(range: NSRange, replacement: String, selection: NSRange) {
        self.range = range
        self.replacement = replacement
        self.selection = selection
    }

    /// The text this edit produces. Used by tests and by callers that have no text view.
    public func applied(to text: String) -> String {
        (text as NSString).replacingCharacters(in: range, with: replacement)
    }
}

/// Text-view behaviors that make items cheap to type.
///
/// These operate on the buffer directly rather than on a `Document`, deliberately: an item is
/// a `- ` and some characters, and routing that through the document model would create a
/// second, subtly different notion of "insert an item" living beside roll's.
///
/// The logic is here rather than in the shells so both platforms behave identically and the
/// behaviour is testable without a text view.
public enum EditorBehavior {
    /// Return at the end of an item continues the list; return on an empty item ends it.
    ///
    /// This is the convenience Notes provides, without the widget. It matters most on iOS,
    /// where typing `-` means switching to the numeric keyboard plane for every single item.
    public static func newline(in text: String, at selection: NSRange) -> EditResult {
        let full = text as NSString
        let lineRange = lineRange(in: full, containing: selection.location)
        let line = full.substring(with: lineRange)

        guard case .item(let item) = Grammar.classify(line) else {
            return edit(replacing: selection, with: "\n")
        }

        // Return on an empty item removes the marker and leaves the caret on the now-blank
        // line -- it ends the list rather than growing an orphan, and without inserting a
        // second newline the way a plain return would.
        if item.text.trimmingCharacters(in: .whitespaces).isEmpty {
            return edit(replacing: lineRange, with: "")
        }
        return edit(replacing: selection, with: "\n" + Grammar.itemMarker)
    }

    /// Adds or removes the `- ` on every line the selection touches.
    ///
    /// Promoting a stray line to an item, or demoting one, is a single action. If any touched
    /// line is not an item they all become items; otherwise they are all demoted.
    public static func toggleItem(in text: String, at selection: NSRange) -> EditResult {
        let full = text as NSString
        let lines = lineRanges(in: full, intersecting: selection)
        guard let first = lines.first, let last = lines.last else {
            return EditResult(range: selection, replacement: "", selection: selection)
        }

        let contents = lines.map { full.substring(with: $0) }
        // If anything touched is not yet an item, promote them all; otherwise demote.
        let makeItems = contents.contains { line in
            if case .item = Grammar.classify(line) { return false }
            return !line.trimmingCharacters(in: .whitespaces).isEmpty
        }

        let updated = contents.map { makeItems ? addingMarker(to: $0) : removingMarker(from: $0) }
        let span = NSRange(
            location: first.location, length: NSMaxRange(last) - first.location
        )
        let replacement = updated.joined(separator: "\n")
        let shift = replacement.utf16.count - span.length

        // A caret moves with the text; a range grows or shrinks with it. Treating a caret
        // as a range would leave the marker selected after a toggle.
        let updatedSelection = selection.length == 0
            ? NSRange(location: max(0, selection.location + shift), length: 0)
            : NSRange(location: selection.location, length: max(0, selection.length + shift))

        return EditResult(range: span, replacement: replacement, selection: updatedSelection)
    }

    /// The edit that opens a tag on the caret's item, ready for a name.
    ///
    /// Writes only the `[`, because what follows is typed: the name filters a list of the
    /// tags already in the file, and a name nothing matches is simply a new tag. Writing
    /// `[] ` instead would leave the closing bracket sitting past the caret, and accepting a
    /// suggestion -- which brings its own -- would produce two.
    ///
    /// At the start of the item's text, never at the caret. A tag is `[work]` at the very
    /// beginning of an item; brackets dropped mid-sentence are not a tag at all, and the
    /// grammar reads them as prose.
    ///
    /// Replaces a tag already there, rather than nesting inside it. An item has one tag or
    /// none, so reaching for the tag button on a tagged item can only mean changing it.
    ///
    /// Returns `nil` when the caret is not in an item, because then there is no tag position.
    public static func openingTag(in text: String, at selection: NSRange) -> EditResult? {
        guard let replaced = tagRange(in: text, at: selection) else { return nil }
        return EditResult(
            range: replaced,
            replacement: CompletionKind.tagName.opening,
            selection: NSRange(
                location: replaced.location + (CompletionKind.tagName.opening as NSString).length,
                length: 0
            )
        )
    }

    /// What a tag occupies on the caret's line, or the empty range where one would go.
    private static func tagRange(in text: String, at selection: NSRange) -> NSRange? {
        let full = text as NSString
        let line = lineRange(in: full, containing: selection.location)
        let raw = full.substring(with: line)
        guard case .item(let item) = Grammar.classify(raw),
              let marker = Highlighting.markerSpan(of: raw)
        else { return nil }

        guard let tag = item.tag else {
            return NSRange(location: line.location + marker.location + marker.length, length: 0)
        }
        // The old tag, and the space after it if there is one -- what replaces it brings its
        // own, and two would be a change to text the user did not ask for.
        let after = tag.span.location + tag.span.length
        let trailing = after < (raw as NSString).length
            && isBlank((raw as NSString).character(at: after)) ? 1 : 0
        return NSRange(
            location: line.location + tag.span.location, length: tag.span.length + trailing
        )
    }

    /// The edit that opens a `@schedule(` at the caret, leaving the caret inside it.
    ///
    /// Only the opening: the argument is chosen afterwards from the completion the opening
    /// creates, which is the same state typing the annotation by hand arrives in. One path
    /// to an argument rather than two, and nothing is written that a `nil` argument would
    /// have to take back -- abandoning the completion leaves a bare `@schedule(` the user
    /// can see and delete, not a value they never picked.
    ///
    /// `nil` where there is nothing to open: off an item, where an annotation means nothing,
    /// and inside a completion already, where a second opening would nest inside the first.
    public static func openingSchedule(in text: String, at selection: NSRange) -> EditResult? {
        let full = text as NSString
        let caret = min(max(selection.location, 0), full.length)
        let line = lineRange(in: full, containing: caret)
        guard case .item = Grammar.classify(full.substring(with: line)) else { return nil }
        guard completionContext(in: text, at: NSRange(location: caret, length: 0)) == nil
        else { return nil }

        let replaced = NSRange(
            location: caret, length: min(selection.length, full.length - caret)
        )
        return edit(
            replacing: replaced,
            with: separator(before: caret, in: full) + ScheduleAnnotation.opening
        )
    }

    /// A space where an annotation would otherwise run into the last word, and the grammar
    /// would read the two as one token.
    private static func separator(before caret: Int, in full: NSString) -> String {
        caret > 0 && !isBlank(full.character(at: caret - 1)) ? " " : ""
    }

    private static func isBlank(_ unit: unichar) -> Bool {
        unit == 0x20 || unit == 0x09 || unit == 0x0A
    }

    /// The smallest replacement that turns `old` into `new`, or `nil` if they already match.
    ///
    /// A roll and an accepted fix-it both arrive as a whole new journal, and replacing the
    /// buffer wholesale made the undo unit the whole journal too -- so undoing a roll left
    /// every line selected, because AppKit selects whatever a text undo put back. Narrowing
    /// the edit to the part that actually changed makes the undo unit the change itself: a
    /// roll prepends, so taking it back leaves a caret where the new block had been.
    ///
    /// It also spares TextKit relaying out years of history for an edit that touched the top
    /// of the file.
    public static func minimalEdit(from old: String, to new: String) -> EditResult? {
        guard old != new else { return nil }
        let old = old as NSString
        let new = new as NSString

        let shorter = min(old.length, new.length)
        var prefix = 0
        while prefix < shorter, old.character(at: prefix) == new.character(at: prefix) {
            prefix += 1
        }
        var suffix = 0
        while suffix < shorter - prefix,
              old.character(at: old.length - 1 - suffix)
                  == new.character(at: new.length - 1 - suffix) {
            suffix += 1
        }

        // Snap both ends onto character boundaries. The common run is measured in UTF-16
        // code units, and half of a surrogate pair is not a character -- handing one to a
        // text storage hands it something that is not text.
        if prefix < old.length {
            prefix = min(prefix, old.rangeOfComposedCharacterSequence(at: prefix).location)
        }
        var start = old.length - suffix
        if start < old.length {
            let sequence = old.rangeOfComposedCharacterSequence(at: start)
            if sequence.location < start { start = NSMaxRange(sequence) }
        }
        suffix = min(old.length - start, shorter - prefix)

        let range = NSRange(location: prefix, length: old.length - suffix - prefix)
        let replacement = new.substring(
            with: NSRange(location: prefix, length: new.length - suffix - prefix)
        )
        return EditResult(
            range: range,
            replacement: replacement,
            selection: NSRange(location: prefix + (replacement as NSString).length, length: 0)
        )
    }

    /// The edit for typing `insertion`, folded together with any rewrite it triggers.
    ///
    /// Returns `nil` when the keystroke needs no special handling, so the text view inserts it
    /// normally and keeps its own typing coalescence.
    ///
    /// This exists so closing an annotation is a *single* undoable edit. Rewriting afterwards
    /// from a change notification is re-entrant: it breaks the text view's coalescence and
    /// leaves the rewrite as a separate undo step, so one undo restores `tuesday` and a second
    /// is needed to remove the paren.
    public static func typing(
        _ insertion: String, in text: String, at range: NSRange
    ) -> EditResult? {
        // A multi-line insertion is a paste, not typing, and is not worth folding.
        guard !insertion.contains("\n") else { return nil }

        // Everything below stays inside the caret's own line. This runs on *every*
        // keystroke, and an annotation can only ever be closed by a character on the line
        // holding it -- so a version that rebuilt the whole journal first was paying for
        // years of history to decide, almost always, that there was nothing to do.
        let full = text as NSString
        let line = lineRange(in: full, containing: range.location)
        guard range.location >= line.location, NSMaxRange(range) <= NSMaxRange(line)
        else { return nil }

        let local = NSRange(location: range.location - line.location, length: range.length)
        let prospective = (full.substring(with: line) as NSString)
            .replacingCharacters(in: local, with: insertion)
        let caret = local.location + insertion.utf16.count
        guard let rewrite = canonicalization(ofLine: prospective, caret: caret) else { return nil }

        // Expressed as one replacement of the affected line, in the original text's
        // coordinates, so the text view only ever sees a single change.
        return EditResult(
            range: line,
            replacement: rewrite.applied(to: prospective),
            selection: NSRange(location: line.location + rewrite.selection.location, length: 0)
        )
    }

    /// Rewrites a just-completed `@schedule(...)` to its canonical form.
    ///
    /// Natural language is only an input convenience: `@schedule(tuesday)` becomes
    /// `@schedule(9/1/2026)` the moment the closing paren is typed, so the file never stores
    /// something whose meaning depends on when it is read. A misparse shows up immediately,
    /// at the keyboard, rather than at a roll weeks later.
    ///
    /// Returns `nil` when there is nothing to do -- no annotation, still being typed, the
    /// argument unreadable, or already canonical.
    ///
    /// Prefer `typing(_:in:at:)` from a text view: rewriting *after* the fact, from a change
    /// notification, is re-entrant and leaves the rewrite as its own undo step.
    public static func canonicalizeAnnotation(in text: String, at caret: Int) -> EditResult? {
        let full = text as NSString
        let line = lineRange(in: full, containing: caret)
        guard let rewrite = canonicalization(
            ofLine: full.substring(with: line), caret: caret - line.location
        ) else { return nil }

        // Back into the whole text's coordinates.
        return EditResult(
            range: NSRange(
                location: line.location + rewrite.range.location, length: rewrite.range.length
            ),
            replacement: rewrite.replacement,
            selection: NSRange(location: line.location + rewrite.selection.location, length: 0)
        )
    }

    /// The same rewrite, for one line and in that line's own coordinates.
    ///
    /// The line is all the information the decision needs, which is what lets `typing` reach
    /// it without assembling the rest of the journal first.
    static func canonicalization(ofLine line: String, caret: Int) -> EditResult? {
        guard case .item(let item) = Grammar.classify(line),
              let annotation = item.annotation
        else { return nil }

        // Only once the caret has passed the closing paren: rewriting mid-argument would
        // fight the typing.
        let span = annotation.span
        guard caret >= span.location + span.length else { return nil }

        guard let canonical = NaturalDates.canonicalizing(annotation.argument),
              canonical != annotation.argument
        else { return nil }

        let argumentStart = span.location + ScheduleAnnotation.opening.utf16.count
        let argumentLength = annotation.argument.utf16.count
        let shift = canonical.utf16.count - argumentLength

        return EditResult(
            range: NSRange(location: argumentStart, length: argumentLength),
            replacement: canonical,
            selection: NSRange(location: caret + shift, length: 0)
        )
    }

    // MARK: - Marker manipulation

    private static func addingMarker(to line: String) -> String {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
        if case .item = Grammar.classify(line) { return line }
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        return indent + Grammar.itemMarker + line.dropFirst(indent.count)
    }

    private static func removingMarker(from line: String) -> String {
        guard case .item(let item) = Grammar.classify(line) else { return line }
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        return indent + item.text
    }

    // MARK: - Line geometry

    private static func edit(replacing range: NSRange, with insertion: String) -> EditResult {
        EditResult(
            range: range,
            replacement: insertion,
            selection: NSRange(location: range.location + insertion.utf16.count, length: 0)
        )
    }

    /// The line holding `location`, without its terminator.
    ///
    /// `NSString` rather than an array of the whole text's UTF-16: this is called on every
    /// keystroke, and walking outwards from the caret costs the length of one line where
    /// materializing the journal's code units cost all of it.
    static func lineRange(in text: NSString, containing location: Int) -> NSRange {
        let clamped = min(max(location, 0), text.length)
        var start = 0
        var contentsEnd = 0
        var end = 0
        text.getLineStart(
            &start, end: &end, contentsEnd: &contentsEnd,
            for: NSRange(location: clamped, length: 0)
        )
        return NSRange(location: start, length: contentsEnd - start)
    }

    static func lineRanges(in text: NSString, intersecting selection: NSRange) -> [NSRange] {
        var ranges: [NSRange] = []
        var cursor = min(max(selection.location, 0), text.length)
        let end = min(selection.location + selection.length, text.length)
        repeat {
            let range = lineRange(in: text, containing: cursor)
            ranges.append(range)
            cursor = NSMaxRange(range) + 1
        } while cursor <= end
        return ranges
    }
}
