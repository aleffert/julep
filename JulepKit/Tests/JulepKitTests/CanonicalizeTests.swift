import Foundation
import Testing
@testable import JulepKit

@Suite("Rewriting annotations on entry")
struct CanonicalizeTests {
    private func rewritten(_ text: String) -> String? {
        EditorBehavior.resolvingAnnotation(in: text, at: (text as NSString).length)?
            .applied(to: text)
    }

    /// The file must never store something whose meaning depends on when it is read.
    @Test func naturalLanguageBecomesAConcreteDate() {
        guard let result = rewritten("- renew passport @schedule(tuesday)") else {
            Issue.record("nothing rewritten"); return
        }
        #expect(result.wholeMatch(of: #/- renew passport @schedule\(\d{1,2}/\d{1,2}/\d{4}\)/#) != nil,
                "got: \(result)")
    }

    /// A repeat is meaningless resolved, so it is left exactly as typed.
    @Test func repeatsAreLeftAlone() {
        #expect(rewritten("- water plants @schedule(every 2 weeks)") == nil)
    }

    @Test func anAlreadyConcreteDateIsNotRewritten() {
        #expect(rewritten("- renew passport @schedule(9/8/2026)") == nil)
    }

    /// Rewriting mid-argument would fight the typing.
    @Test func nothingHappensUntilTheAnnotationIsClosed() {
        let partial = "- renew passport @schedule(tuesd"
        #expect(EditorBehavior.resolvingAnnotation(
            in: partial, at: (partial as NSString).length) == nil)
    }

    @Test func anUnreadableArgumentIsLeftForTheUserToFix() {
        #expect(rewritten("- renew passport @schedule(sometime)") == nil)
    }

    @Test func linesWithoutAnnotationsAreUntouched() {
        #expect(rewritten("- just an item") == nil)
        #expect(rewritten("sunday 8/30/2026") == nil)
    }

    /// Closing the annotation is one edit, not an insertion followed by a rewrite -- so a
    /// single undo takes the whole thing back.
    @Test func closingTheAnnotationIsASingleEdit() {
        let before = "- renew passport @schedule(tuesday"
        guard let edit = EditorBehavior.typing(
            ")", in: before, at: NSRange(location: (before as NSString).length, length: 0)
        ) else {
            Issue.record("the closing paren was not folded with the rewrite"); return
        }
        let after = edit.applied(to: before)
        #expect(!after.contains("tuesday"), "got: \(after)")
        #expect(after.wholeMatch(of: #/- renew passport @schedule\(\d{1,2}/\d{1,2}/\d{4}\)/#) != nil,
                "got: \(after)")
    }

    /// An ordinary keystroke is left alone, so the text view keeps coalescing its own typing.
    @Test("Ordinary typing is not intercepted", arguments: [
        ("- renew passport", "x"),
        ("- a @schedule(tue", "s"),
        ("- a @schedule(9/8/2026", ")"),
    ])
    func ordinaryTypingIsNotIntercepted(_ input: (text: String, key: String)) {
        #expect(EditorBehavior.typing(
            input.key, in: input.text,
            at: NSRange(location: (input.text as NSString).length, length: 0)
        ) == nil)
    }

    /// An argument is read against the block it was written in, never against today.
    @Test func anArgumentIsReadAgainstItsOwnBlock() {
        let text = """
        tuesday 4/21/2026
        - renew passport @schedule(in 3 weeks)
        """
        guard let result = EditorBehavior.resolvingAnnotation(
            in: text, at: (text as NSString).length
        )?.applied(to: text) else {
            Issue.record("nothing rewritten"); return
        }
        #expect(result.hasSuffix("@schedule(5/12/2026)"), "got: \(result)")
    }

    /// A one-day deferral is filed under `next` instead of being written -- see
    /// `Document.filingDeferralIntoNext(lineIndex:)`.
    @Test func closingATomorrowAnnotationFilesItIntoNext() {
        let before = """
        tuesday 4/21/2026
        - renew passport @schedule(tomorrow
        """
        guard let edit = EditorBehavior.typing(
            ")", in: before, at: NSRange(location: (before as NSString).length, length: 0)
        ) else {
            Issue.record("the paren was not folded with the move"); return
        }
        #expect(edit.applied(to: before) == """
        tuesday 4/21/2026
        next
        - renew passport
        """)
    }

    /// The picker writes the date rather than the word, so filing cannot hang off the
    /// natural-language rewrite: there is nothing to rewrite, and it still has to fire.
    @Test func aPickedDateFilesJustTheSame() {
        let before = """
        tuesday 4/21/2026
        - renew passport @schedule(4/22/2026
        """
        guard let edit = EditorBehavior.typing(
            ")", in: before, at: NSRange(location: (before as NSString).length, length: 0)
        ) else {
            Issue.record("an already-canonical date was not filed"); return
        }
        #expect(edit.applied(to: before) == """
        tuesday 4/21/2026
        next
        - renew passport
        """)
    }

    /// The caret keeps its place relative to the text, not its absolute offset.
    @Test func theCaretFollowsTheRewrite() {
        let text = "- a @schedule(tomorrow)"
        guard let result = EditorBehavior.resolvingAnnotation(
            in: text, at: (text as NSString).length) else {
            Issue.record("nothing rewritten"); return
        }
        #expect(result.selection.location == (result.applied(to: text) as NSString).length)
    }
}
