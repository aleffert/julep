import Foundation
import Testing
@testable import JulepKit

/// What the caret is in the middle of typing, and what to offer for it.
///
/// One mechanism serves the `@schedule(` argument and the `[tag]` name, so most of these are
/// written against both kinds -- a rule that holds for one and not the other is the bug this
/// abstraction is meant to make impossible.
@Suite("Completion context")
struct CompletionContextTests {
    private func context(_ text: String, caret: Int) -> CompletionContext? {
        EditorBehavior.completionContext(in: text, at: NSRange(location: caret, length: 0))
    }

    /// The caret sits after `[`, so the tag name is empty and waiting.
    @Test func anOpenBracketAtTheStartOfAnItemStartsATag() {
        let found = context("- [", caret: 3)
        #expect(found?.kind == .tagName)
        #expect(found?.typed == "")
        #expect(found?.range == NSRange(location: 3, length: 0))
    }

    @Test func whatHasBeenTypedIsReported() {
        let found = context("- [wo", caret: 5)
        #expect(found?.kind == .tagName)
        #expect(found?.typed == "wo")
        #expect(found?.range == NSRange(location: 3, length: 2))
    }

    @Test func anOpenScheduleArgumentIsFound() {
        let text = "- renew passport @schedule(tue"
        let found = context(text, caret: (text as NSString).length)
        #expect(found?.kind == .scheduleArgument)
        #expect(found?.typed == "tue")
    }

    /// Past the closing delimiter there is nothing left to finish.
    @Test("Completed constructs offer nothing", arguments: [
        ("- [work] unpack", 8),
        ("- [work] unpack", 15),
        ("- renew @schedule(9/8/2026)", 27),
    ])
    func closedConstructsAreNotCompletions(_ text: String, _ caret: Int) {
        #expect(context(text, caret: caret) == nil)
    }

    /// Inside one that is already closed, though, the user is rewriting it -- and finishing
    /// what they are rewriting is exactly the help wanted.
    @Test func acaretInsideAnExistingConstructStillCompletes() {
        let found = context("- [work] unpack", caret: 7)
        #expect(found?.kind == .tagName)
        #expect(found?.typed == "work")

        let schedule = context("- renew @schedule(9/8/2026)", caret: 22)
        #expect(schedule?.kind == .scheduleArgument)
        #expect(schedule?.typed == "9/8/")
    }

    /// A tag is only a tag at the very start of an item. A bracket in the middle of a
    /// sentence is an ordinary character, and completing it would invent a convention.
    @Test func aBracketMidLineIsNotATag() {
        #expect(context("- call mom [wo", caret: 14) == nil)
    }

    @Test func aBracketOnANonItemLineIsNotATag() {
        #expect(context("monday 8/31/2026 [wo", caret: 20) == nil)
        #expect(context("[wo", caret: 3) == nil)
    }

    @Test func indentationDoesNotHideTheTagPosition() {
        #expect(context("   - [wo", caret: 8)?.typed == "wo")
    }

    @Test func aSelectionIsNotACaretAndOffersNothing() {
        #expect(EditorBehavior.completionContext(
            in: "- [wo", at: NSRange(location: 3, length: 2)
        ) == nil)
    }

    @Test func theRightLineIsUsedInAMultiLineJournal() {
        let text = "monday 8/31/2026\n- [work] unpack\n- [fe"
        #expect(context(text, caret: (text as NSString).length)?.typed == "fe")
    }

    // MARK: - Accepting

    @Test func acceptingATagClosesItAndLeavesRoomForTheText() {
        let text = "- [wo"
        guard let found = context(text, caret: 5) else { Issue.record("no context"); return }
        let edit = EditorBehavior.accepting(
            CompletionOption(title: "work", insertion: "work"), for: found, in: text
        )
        #expect(edit.applied(to: text) == "- [work] ")
        #expect(edit.selection == NSRange(location: 9, length: 0))
    }

    @Test func acceptingAScheduleArgumentClosesTheParen() {
        let text = "- renew passport @schedule(tue"
        guard let found = context(text, caret: (text as NSString).length)
        else { Issue.record("no context"); return }
        let edit = EditorBehavior.accepting(
            CompletionOption(title: "Tomorrow", insertion: "9/8/2026"), for: found, in: text
        )
        #expect(edit.applied(to: text) == "- renew passport @schedule(9/8/2026)")
    }

    /// Picking a deferral to the day after the block is the same decision as typing it, and
    /// resolves the same way: filed into `next`, with the annotation dropped. Which used to
    /// depend on which shell you were holding -- the Mac folded it by re-entering the typing
    /// delegate, and the phone guarded against exactly that.
    @Test func acceptingAOneDayDeferralFilesItIntoNext() {
        let text = "monday 8/31/2026\n- renew passport @schedule("
        guard let found = context(text, caret: (text as NSString).length)
        else { Issue.record("no context"); return }
        let edit = EditorBehavior.accepting(
            CompletionOption(title: "Tomorrow", insertion: "9/1/2026"), for: found, in: text
        )
        #expect(edit.applied(to: text) == "monday 8/31/2026\nnext\n- renew passport")
    }

    /// Anything further out is a date the journal should keep saying, so the annotation stays.
    @Test func acceptingAFurtherDeferralKeepsTheAnnotation() {
        let text = "monday 8/31/2026\n- renew passport @schedule("
        guard let found = context(text, caret: (text as NSString).length)
        else { Issue.record("no context"); return }
        let edit = EditorBehavior.accepting(
            CompletionOption(title: "Next week", insertion: "9/8/2026"), for: found, in: text
        )
        #expect(edit.applied(to: text)
            == "monday 8/31/2026\n- renew passport @schedule(9/8/2026)")
    }

    /// Whatever is accepted has to read back as the thing it was meant to be.
    @Test func anAcceptedCompletionParses() {
        let text = "- [wo"
        guard let found = context(text, caret: 5) else { Issue.record("no context"); return }
        let line = EditorBehavior.accepting(
            CompletionOption(title: "work", insertion: "work"), for: found, in: text
        ).applied(to: text)
        guard case .item(let item) = Grammar.classify(line) else {
            Issue.record("not an item: \(line)")
            return
        }
        #expect(item.tag?.name == "work")
    }
}

@Suite("Completion options")
struct CompletionOptionsTests {
    private let document = Document(Corpus.text)

    private func tagContext(_ typed: String) -> CompletionContext {
        CompletionContext(kind: .tagName, range: NSRange(location: 0, length: 0), typed: typed)
    }

    /// Nothing typed: the handful worth offering unprompted.
    @Test func anEmptyTagOffersTheRecentSix() {
        let offered = document.completions(for: tagContext("")).map(\.title)
        #expect(offered == document.recentTags())
        #expect(offered.count <= 6)
    }

    /// The cap is what typing is for getting past. The corpus has more tags than it offers
    /// unprompted, and a typed prefix has to be able to reach them.
    @Test func typingReachesTagsBeyondTheOfferedSix() {
        let all = document.tags
        #expect(all.count > 6, "the corpus no longer exercises this")
        guard let buried = all.dropFirst(6).first else { return }
        let offered = document.completions(for: tagContext(buried)).map(\.title)
        #expect(offered.contains(buried), "typed \(buried), offered \(offered)")
    }

    @Test func prefixMatchesComeBeforeMerelyContainedOnes() {
        let options = [
            CompletionOption(title: "unread", insertion: "unread"),
            CompletionOption(title: "read", insertion: "read"),
        ]
        // Built by hand rather than from the corpus, so the ordering rule is what is tested.
        let ranked = Document(lines: []).ranked(options, matching: "read")
        #expect(ranked.map(\.title) == ["read", "unread"])
    }

    /// `tags` is in first-appearance order and the journal is newest first, so recency is
    /// already the order before matching reorders it -- and has to survive that.
    @Test func recencyBreaksTiesAmongEqualMatches() {
        let options = ["work", "workout", "worklog"]
            .map { CompletionOption(title: $0, insertion: $0) }
        let ranked = Document(lines: []).ranked(options, matching: "work")
        #expect(ranked.map(\.title) == options.map(\.title))
    }

    @Test func matchingIsCaseInsensitive() {
        let options = [CompletionOption(title: "Work", insertion: "work")]
        #expect(!Document(lines: []).ranked(options, matching: "WOR").isEmpty)
    }

    @Test func nothingMatchesNothing() {
        #expect(document.completions(for: tagContext("zzzzz")).isEmpty)
    }

    private func scheduleContext(_ typed: String) -> CompletionContext {
        CompletionContext(
            kind: .scheduleArgument, range: NSRange(location: 0, length: 0), typed: typed
        )
    }

    /// A schedule suggestion is written as the date it means, and shows that date beside the
    /// label so picking "Next week" never hides which day that was.
    @Test func aScheduleOptionCarriesItsConcreteArgument() {
        let offered = document.completions(for: scheduleContext(""))
        #expect(offered.contains { $0.title == "Next week" && $0.detail == $0.insertion })
        #expect(offered.contains { $0.title == "Every week" && $0.insertion == "every week" })
    }

    /// Offered against the block being typed into, and `Tomorrow` says what it will actually
    /// do: the date it writes is taken straight back out again when the line is filed under
    /// `next`, so showing that date would describe something that does not happen.
    @Test func tomorrowIsOfferedAgainstTheBlockAndReadsAsNext() {
        let document = Document("""
        tuesday 4/21/2026
        - a
        """)
        let context = CompletionContext(
            kind: .scheduleArgument, range: NSRange(location: 20, length: 0), typed: ""
        )
        let tomorrow = document.completions(for: context).first { $0.title == "Tomorrow" }
        #expect(tomorrow?.insertion == "4/22/2026")
        #expect(tomorrow?.detail == "next")
    }

    /// Unlike tags, the schedule suggestions are not capped: the set is fixed and every one
    /// of them is worth a tap. The last repeat is the one a cap would drop.
    @Test func everyScheduleSuggestionIsOfferedUnprompted() {
        let offered = document.completions(for: scheduleContext("")).map(\.insertion)
        #expect(offered.count == ScheduleSuggestions.soon().count + ScheduleSuggestions.repeats.count)
        #expect(offered.contains("every month"))
    }
}
