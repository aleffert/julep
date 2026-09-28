import Foundation
import Testing
@testable import JulepKit

@Suite("JournalSearch")
struct JournalSearchTests {
    let journal = """
    monday 9/21/2026
    - call the dentist
    done
    - booked the dentist

    sunday 9/20/2026
    - dentist paperwork

    """

    /// Every occurrence, found the long way. The point of `JournalSearch` is not having to
    /// keep this list; a test is the one place it is worth building.
    private func occurrences(of term: String, in text: String) -> [NSRange] {
        let full = text as NSString
        var found: [NSRange] = []
        var start = 0
        while start < full.length {
            let match = full.range(
                of: term,
                options: [],
                range: NSRange(location: start, length: full.length - start)
            )
            guard match.location != NSNotFound else { break }
            found.append(match)
            start = NSMaxRange(match)
        }
        return found
    }

    @Test func nextFindsTheFirstMatchFromTheTop() {
        #expect(JournalSearch.next(from: 0, of: "dentist", in: journal)
            == occurrences(of: "dentist", in: journal).first)
    }

    @Test func nextIncludesAMatchStartingExactlyAtTheLocation() {
        let first = occurrences(of: "dentist", in: journal)[0]
        #expect(JournalSearch.next(from: first.location, of: "dentist", in: journal) == first)
    }

    @Test func steppingWalksEveryMatchInOrderThenWrapsToTheFirst() {
        let all = occurrences(of: "dentist", in: journal)
        #expect(all.count == 3)

        var walked: [NSRange] = []
        var location = 0
        for _ in 0...all.count {
            guard let match = JournalSearch.next(from: location, of: "dentist", in: journal)
            else { break }
            walked.append(match)
            location = NSMaxRange(match)
        }
        #expect(walked == all + [all[0]])
    }

    @Test func previousWalksBackwardsThenWrapsToTheLast() {
        let all = occurrences(of: "dentist", in: journal)
        var walked: [NSRange] = []
        var location = (journal as NSString).length
        for _ in 0...all.count {
            guard let match = JournalSearch.previous(from: location, of: "dentist", in: journal)
            else { break }
            walked.append(match)
            location = match.location
        }
        #expect(walked == Array(all.reversed()) + [all.last!])
    }

    @Test func previousFromTheTopComesRoundToTheBottom() {
        #expect(JournalSearch.previous(from: 0, of: "dentist", in: journal)
            == occurrences(of: "dentist", in: journal).last)
    }

    @Test func caseAndDiacriticsAreIgnored() {
        let text = "- rsvp to the café\n"
        #expect(JournalSearch.next(from: 0, of: "CAFE", in: text) != nil)
        #expect(JournalSearch.next(from: 0, of: "RSVP", in: text) != nil)
    }

    @Test func aTermThatIsNotThereFindsNothing() {
        #expect(JournalSearch.next(from: 0, of: "kayak", in: journal) == nil)
        #expect(JournalSearch.previous(from: 0, of: "kayak", in: journal) == nil)
    }

    @Test func anEmptyTermFindsNothing() {
        #expect(JournalSearch.next(from: 0, of: "", in: journal) == nil)
        #expect(JournalSearch.previous(from: 0, of: "", in: journal) == nil)
    }

    /// The anchor is an offset into text the user may have edited since, so it arrives
    /// unreliable by construction rather than by accident.
    @Test func anOffsetOutsideTheTextIsClamped() {
        #expect(JournalSearch.next(from: -50, of: "dentist", in: journal) != nil)
        #expect(JournalSearch.next(from: 9_000, of: "dentist", in: journal) != nil)
        #expect(JournalSearch.previous(from: -50, of: "dentist", in: journal) != nil)
        #expect(JournalSearch.previous(from: 9_000, of: "dentist", in: journal) != nil)
    }

    /// The wrap searches the whole text rather than the part above where it started, so a
    /// match lying across that boundary is still found -- it belongs to neither half.
    @Test func aMatchStraddlingTheStartIsFoundByTheWrap() {
        #expect(JournalSearch.next(from: 3, of: "cab", in: "abcabc")
            == NSRange(location: 2, length: 3))
        #expect(JournalSearch.previous(from: 3, of: "cab", in: "abcabc")
            == NSRange(location: 2, length: 3))
    }

    @Test func searchingAnEmptyJournalFindsNothing() {
        #expect(JournalSearch.next(from: 0, of: "dentist", in: "") == nil)
        #expect(JournalSearch.previous(from: 0, of: "dentist", in: "") == nil)
    }
}
