import Foundation

/// A convention the app can help finish once the user has opened it.
///
/// There are two so far -- the argument of a `@schedule(`, and the name inside a `[tag]` --
/// and they behave identically: an opening delimiter, some text typed against a list of
/// candidates, and a closing delimiter written when one is accepted. A third convention
/// should be a case here and a branch in each switch below, not a second copy of the picker.
public enum CompletionKind: Equatable, Sendable, CaseIterable {
    case scheduleArgument
    case tagName

    /// What opens it. Typing this is what starts a completion.
    public var opening: String {
        switch self {
        case .scheduleArgument: ScheduleAnnotation.opening
        case .tagName: "["
        }
    }

    /// What is written after the accepted text, closing the construct off.
    ///
    /// The tag takes a trailing space as well as its bracket: a tag is followed by the item's
    /// text, and accepting one should leave the caret ready to write it.
    public var closing: String {
        switch self {
        case .scheduleArgument: ScheduleAnnotation.closing
        case .tagName: "] "
        }
    }
}

/// One thing a completion can insert.
public struct CompletionOption: Identifiable, Equatable, Sendable {
    /// What the user reads.
    public var title: String
    /// What gets written. Often the same as `title`; a schedule suggestion differs, because
    /// "Tomorrow" has to be written as the date it actually means.
    public var insertion: String
    /// Shown beside the title, so picking "Tomorrow" never hides what it does. Defaults to
    /// the insertion where that differs from the title, and is given outright where the
    /// insertion is not what the pick leaves in the file.
    public var detail: String?

    public var id: String { insertion }

    public init(title: String, insertion: String, detail: String? = nil) {
        self.title = title
        self.insertion = insertion
        self.detail = detail ?? (title == insertion ? nil : insertion)
    }
}

/// Where the caret is, when it is in the middle of one of these.
public struct CompletionContext: Equatable, Sendable {
    public var kind: CompletionKind
    /// The text typed so far, as a range in the whole document.
    public var range: NSRange
    /// That range's contents, which the candidates are filtered against.
    public var typed: String

    public init(kind: CompletionKind, range: NSRange, typed: String) {
        self.kind = kind
        self.range = range
        self.typed = typed
    }
}

extension EditorBehavior {
    /// What the caret is in the middle of typing, if anything.
    ///
    /// Only ever an *unclosed* construct. A finished `@schedule(9/8/2026)` or `[work]` is
    /// something the user has already decided; reopening a picker over it would fight them
    /// for a line they are done with.
    public static func completionContext(
        in text: String, at selection: NSRange
    ) -> CompletionContext? {
        guard selection.length == 0 else { return nil }
        let full = text as NSString
        let caret = min(max(selection.location, 0), full.length)
        let line = lineRange(in: full, containing: caret)
        let raw = full.substring(with: line)
        guard case .item = Grammar.classify(raw) else { return nil }

        let local = caret - line.location
        for kind in CompletionKind.allCases {
            guard let start = openingEnd(of: kind, in: raw, before: local) else { continue }
            // Only what lies between the opening and the caret. A construct that closes
            // *after* the caret is one being edited in place -- retyping the name inside an
            // existing `[work]` -- and offering to finish it there is the point.
            let between = (raw as NSString).substring(
                with: NSRange(location: start, length: local - start)
            )
            guard !between.contains(kind.closingDelimiter) else { continue }
            return CompletionContext(
                kind: kind,
                range: NSRange(location: line.location + start, length: local - start),
                typed: (raw as NSString).substring(
                    with: NSRange(location: start, length: local - start)
                )
            )
        }
        return nil
    }

    /// Where the text being completed begins, for an opening that sits before the caret with
    /// nothing but candidate text in between.
    private static func openingEnd(of kind: CompletionKind, in raw: String, before local: Int) -> Int? {
        let text = raw as NSString
        guard local <= text.length else { return nil }
        let prefix = text.substring(to: local) as NSString
        let opening = prefix.range(of: kind.opening, options: .backwards)
        guard opening.location != NSNotFound else { return nil }

        let start = NSMaxRange(opening)
        // A tag is only a tag at the very start of the item, so a bracket anywhere else is an
        // ordinary character and completing it would be inventing a convention.
        if kind == .tagName {
            guard let marker = Highlighting.markerSpan(of: raw),
                  opening.location == marker.location + marker.length
            else { return nil }
        }
        guard !prefix.substring(from: start).contains("\n") else { return nil }
        return start
    }

    /// The edit that accepts `option`, closing the construct behind it -- together with any
    /// rewrite that closing triggers.
    ///
    /// Folded for the same reason typing is: closing a `@schedule(...)` can file the item
    /// into `next` or rewrite its argument concrete, and doing that afterwards would leave a
    /// second undo step. It has to be asked for here rather than left to happen on the way
    /// out. On the Mac it used to happen by accident -- `apply` ran through the delegate that
    /// folds typing, and re-entered it -- while iOS guarded against exactly that re-entrancy.
    /// The same pick therefore filed the item into `next` on one platform and wrote an
    /// annotation on the other.
    ///
    /// `text` is the buffer `context` was computed against.
    public static func accepting(
        _ option: CompletionOption, for context: CompletionContext, in text: String
    ) -> EditResult {
        let replacement = option.insertion + context.kind.closing
        let accepted = EditResult(
            range: context.range,
            replacement: replacement,
            selection: NSRange(
                location: context.range.location + (replacement as NSString).length, length: 0
            )
        )
        let prospective = accepted.applied(to: text)
        guard let resolution = resolvingAnnotation(
            in: prospective, at: accepted.selection.location
        ) else { return accepted }
        // One replacement against the text as it stands, so the pick and what it triggered
        // are a single undoable edit.
        return minimalEdit(from: text, to: resolution.applied(to: prospective)) ?? accepted
    }
}

extension CompletionKind {
    /// The bare closing character, for deciding whether the construct is already finished.
    /// `closing` may carry more than that -- a tag's trailing space -- which must not count.
    var closingDelimiter: String {
        switch self {
        case .scheduleArgument: ScheduleAnnotation.closing
        case .tagName: "]"
        }
    }
}

extension Document {
    /// What to offer for a completion in progress, best first.
    ///
    /// With nothing typed, the handful worth offering unprompted. Once something *is* typed
    /// the cap comes off: reaching the candidates further down is exactly what typing is for.
    public func completions(for context: CompletionContext, limit: Int = 6) -> [CompletionOption] {
        let all: [CompletionOption]
        /// How many to offer before anything has been typed.
        let unprompted: Int
        switch context.kind {
        case .scheduleArgument:
            // Offered against the block being typed into, not today: `Tomorrow` on a line in
            // an older block means the day after *that* block, which is the same rule the
            // annotation is read back by.
            let reference = lineIndex(atUTF16Offset: context.range.location)
                .flatMap { index in blocks.first { $0.range.contains(index) } }?
                .header.date
            all = (ScheduleSuggestions.soon(from: reference ?? NaturalDates.today())
                + ScheduleSuggestions.repeats)
                .map {
                    CompletionOption(title: $0.title, insertion: $0.argument, detail: $0.detail)
                }
            // All of them. The cap is there because a journal can hold hundreds of tags and
            // only the recent few are worth unprompted space; the schedule suggestions are a
            // fixed eight, chosen for being worth exactly that. Cutting them at six drops
            // "every 2 weeks" and "every month" -- which are then unreachable, because
            // typing "every" ranks the ones already shown first.
            unprompted = all.count
        case .tagName:
            all = tags.map { CompletionOption(title: $0, insertion: $0) }
            unprompted = limit
        }
        guard !context.typed.isEmpty else { return Array(all.prefix(unprompted)) }
        return ranked(all, matching: context.typed)
    }

    /// What matches best, first -- with the order it arrived in breaking ties.
    ///
    /// That tiebreak carries more weight than it looks. `tags` is in first-appearance order
    /// and the journal is newest-first, so the list is already sorted by recency before
    /// matching reorders it, and a stable partition is what keeps it that way.
    func ranked(_ options: [CompletionOption], matching typed: String) -> [CompletionOption] {
        let typed = typed.lowercased()
        var prefixed: [CompletionOption] = []
        var contained: [CompletionOption] = []
        for option in options {
            let title = option.title.lowercased()
            let insertion = option.insertion.lowercased()
            if title.hasPrefix(typed) || insertion.hasPrefix(typed) {
                prefixed.append(option)
            } else if title.contains(typed) || insertion.contains(typed) {
                contained.append(option)
            }
        }
        return prefixed + contained
    }
}
