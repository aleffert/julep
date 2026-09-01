import Foundation
import Testing
@testable import JulepKit

/// Where a tag goes, and how an annotation is written.
///
/// Both used to be plain insertions at the caret, which put a tag wherever the caret happened
/// to be -- and the grammar only reads one at the very start of an item, so a tag dropped
/// mid-sentence was not a tag, just brackets in the prose.
@Suite("Tagging")
struct TaggingTests {
    private func opened(_ text: String, caret: Int) -> String? {
        EditorBehavior.openingTag(in: text, at: NSRange(location: caret, length: 0))?
            .applied(to: text)
    }

    /// The bracket goes where a tag goes, not where the caret happens to be.
    @Test func theBracketLandsAtTheStartOfTheItem() {
        #expect(opened("- call mom about the lease", caret: 12) == "- [call mom about the lease")
    }

    @Test func itGoesAfterTheMarkerNotBeforeIt() {
        #expect(opened("- unpack", caret: 8) == "- [unpack")
    }

    @Test func indentationIsPreserved() {
        #expect(opened("   - unpack", caret: 11) == "   - [unpack")
    }

    /// An item has one tag or none, so reaching for the tag button on a tagged item can only
    /// mean changing it -- the old one makes way, trailing space and all.
    @Test func anExistingTagIsReplacedRatherThanNested() {
        #expect(opened("- [work] call the landlord", caret: 20) == "- [call the landlord")
        #expect(opened("- [bb]x", caret: 7) == "- [x")
    }

    /// The caret ends up inside the bracket, which is the position that reads as "a tag with
    /// nothing typed yet" and puts the whole list on offer.
    @Test func theCaretLandsInsideTheBracket() {
        let result = EditorBehavior.openingTag(
            in: "- unpack", at: NSRange(location: 8, length: 0)
        )
        #expect(result?.selection == NSRange(location: 3, length: 0))

        let opened = result?.applied(to: "- unpack") ?? ""
        let context = EditorBehavior.completionContext(
            in: opened, at: NSRange(location: 3, length: 0)
        )
        #expect(context?.kind == .tagName)
        #expect(context?.typed == "")
    }

    /// Opening a tag then accepting a suggestion has to land on a line the grammar reads as
    /// tagged -- with one closing bracket, not the two an `[] ` would have left.
    @Test func openingThenAcceptingProducesAWellFormedTag() {
        let text = "- unpack"
        guard let opened = EditorBehavior.openingTag(
            in: text, at: NSRange(location: 8, length: 0)
        ) else { Issue.record("no edit"); return }
        let withBracket = opened.applied(to: text)

        guard let context = EditorBehavior.completionContext(
            in: withBracket, at: opened.selection
        ) else { Issue.record("no context"); return }
        let line = EditorBehavior.accepting(
            CompletionOption(title: "work", insertion: "work"), for: context
        ).applied(to: withBracket)

        #expect(line == "- [work] unpack")
        guard case .item(let item) = Grammar.classify(line) else {
            Issue.record("not an item: \(line)")
            return
        }
        #expect(item.tag?.name == "work")
    }

    /// Nowhere to put it, so nothing is put anywhere.
    @Test("Lines with no tag position are left alone", arguments: [
        "monday 8/31/2026",
        "done",
        "delta 3 days",
        "",
        "a line the grammar cannot read",
    ])
    func nonItemsAreRefused(_ text: String) {
        #expect(EditorBehavior.openingTag(in: text, at: NSRange(location: 0, length: 0)) == nil)
    }

    @Test func theRightLineIsOpenedInAMultiLineJournal() {
        let text = "monday 8/31/2026\n- unpack\n- water the plants"
        let caret = (text as NSString).range(of: "feed").location
        #expect(opened(text, caret: caret) == "monday 8/31/2026\n- unpack\n- [water the plants")
    }
}

@Suite("Scheduling")
struct SchedulingTests {
    /// The whole path the toolbar button takes: open the annotation, then accept an argument
    /// from the completion the opening creates. Written as one helper because the two halves
    /// are only correct together -- an opening the completion cannot see is a dead end.
    private func scheduled(_ argument: String, _ text: String, caret: Int) -> String {
        let selection = NSRange(location: caret, length: 0)
        let opening = EditorBehavior.openingSchedule(in: text, at: selection)
        let opened = opening?.applied(to: text) ?? text
        guard let context = EditorBehavior.completionContext(
            in: opened, at: opening?.selection ?? selection
        ) else {
            Issue.record("nothing to complete after opening: \(opened)")
            return opened
        }
        return EditorBehavior.accepting(
            CompletionOption(title: argument, insertion: argument), for: context
        ).applied(to: opened)
    }

    /// The toolbar writes only the opening, so the space that keeps the annotation off the
    /// last word is written with it.
    @Test func awholeAnnotationIsWrittenWithASeparatingSpace() {
        #expect(
            scheduled("9/8/2026", "- renew passport", caret: 16)
                == "- renew passport @schedule(9/8/2026)"
        )
    }

    @Test func noSecondSpaceIsAddedWhereThereIsAlreadyOne() {
        #expect(
            scheduled("9/8/2026", "- renew passport ", caret: 17)
                == "- renew passport @schedule(9/8/2026)"
        )
    }

    /// Straight after the marker there is nothing to separate from.
    @Test func noSpaceIsAddedAtTheStartOfAnItem() {
        #expect(scheduled("9/8/2026", "- ", caret: 2) == "- @schedule(9/8/2026)")
    }

    /// Typed by hand, the opening is already there -- and opening a second one inside it
    /// would nest an annotation in its own argument.
    @Test func anAnnotationOpenedByHandIsNotOpenedAgain() {
        let text = "- renew passport @schedule("
        let caret = (text as NSString).length
        #expect(
            EditorBehavior.openingSchedule(in: text, at: NSRange(location: caret, length: 0))
                == nil
        )
        #expect(scheduled("9/8/2026", text, caret: caret) == "- renew passport @schedule(9/8/2026)")
    }

    /// An annotation is a thing an item carries; there is nowhere for one to go on a date
    /// header or a blank line, and the completion would never appear to finish it.
    @Test func nothingIsOpenedOffAnItem() {
        for text in ["monday 8/31/2026", "", "just some prose"] {
            #expect(
                EditorBehavior.openingSchedule(in: text, at: NSRange(location: 0, length: 0))
                    == nil
            )
        }
    }

    /// The caret lands inside the annotation, which is what the suggestion list keys off.
    @Test func theCaretEndsInsideTheOpening() {
        let text = "- renew passport"
        let result = EditorBehavior.openingSchedule(
            in: text, at: NSRange(location: 16, length: 0)
        )
        let opened = result?.applied(to: text)
        #expect(opened == "- renew passport @schedule(")
        #expect(result?.selection.location == (opened.map { ($0 as NSString).length }))
        #expect(
            EditorBehavior.completionContext(in: opened ?? "", at: result?.selection ?? NSRange())?
                .kind == .scheduleArgument
        )
    }

    /// Whatever is written has to read back as the annotation it was meant to be.
    @Test func theResultParsesAsAnAnnotation() {
        for argument in ["9/8/2026", "every 2 weeks"] {
            let line = scheduled(argument, "- renew passport", caret: 16)
            guard case .item(let item) = Grammar.classify(line) else {
                Issue.record("not an item: \(line)")
                continue
            }
            #expect(item.annotation?.argument == argument)
        }
    }
}
