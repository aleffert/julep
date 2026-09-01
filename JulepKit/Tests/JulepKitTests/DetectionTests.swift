import Foundation
import Testing
@testable import JulepKit

/// Phone numbers, emails and links inside items.
///
/// The interesting half of this is what must *not* be found. A journal is full of dates, and
/// a date is exactly the shape a phone-number detector likes -- so the negative cases below
/// are the ones that decide whether the feature is useful or noise.
@Suite("Detection")
struct DetectionTests {
    private func detections(_ raw: String) -> [Detection] {
        Highlighting.detections(inLine: raw, kind: Grammar.classify(raw))
    }

    @Test func aPhoneNumberInAnItemIsFound() {
        let found = detections("- call mom 415-555-0134")
        #expect(found.map(\.kind) == [.phoneNumber])
        #expect(found.first?.text == "415-555-0134")
        #expect(found.first?.url.scheme == "tel")
        // The punctuation is for reading, not for dialling.
        #expect(found.first?.url.absoluteString == "tel:4155550134")
    }

    @Test func anEmailInAnItemIsFound() {
        let found = detections("- email jane@example.com about the lease")
        #expect(found.map(\.kind) == [.emailAddress])
        #expect(found.first?.text == "jane@example.com")
        #expect(found.first?.url.absoluteString == "mailto:jane@example.com")
    }

    @Test func aLinkInAnItemIsFound() {
        let found = detections("- read https://example.com/thing")
        #expect(found.map(\.kind) == [.webLink])
        #expect(found.first?.url.absoluteString == "https://example.com/thing")
    }

    @Test func theSpanCoversExactlyTheDetectedText() {
        let raw = "- call mom 415-555-0134"
        guard let found = detections(raw).first else { Issue.record("nothing found"); return }
        let text = raw as NSString
        #expect(
            text.substring(with: NSRange(location: found.span.location, length: found.span.length))
                == found.text
        )
    }

    // MARK: - What must not be found

    /// The reason detection is confined to item text. A header is a date, and a date run
    /// through a phone detector is a phone number waiting to happen.
    @Test("Structure is never scanned", arguments: [
        "monday 8/31/2026",
        "sunday 6/21/2026",
        "delta 15 days",
        "done",
        "next",
        "",
    ])
    func structuralLinesAreNotScanned(_ raw: String) {
        #expect(detections(raw).isEmpty)
    }

    /// The annotation is a date the app wrote and will read back. Offering to dial it would
    /// be absurd, and styling it as a link would fight the annotation's own colour.
    @Test func anAnnotationIsNotScanned() {
        #expect(detections("- renew passport @schedule(9/8/2026)").isEmpty)
    }

    /// A tag holding something the detector *would* match, so this tests the exclusion
    /// rather than the absence of anything to exclude.
    @Test func aTagIsNotScanned() {
        let raw = "- [jane@example.com] follow up"
        guard case .item(let item) = Grammar.classify(raw), item.tag != nil else {
            Issue.record("the grammar did not read a tag here, so nothing is being excluded")
            return
        }
        #expect(detections(raw).isEmpty)
    }

    /// A tag and an annotation on the same line as a real phone number: the number is still
    /// found, and it alone.
    @Test func structureIsSkippedWithoutHidingTheProseAroundIt() {
        let found = detections("- [work] call 415-555-0134 @schedule(9/8/2026)")
        #expect(found.map(\.text) == ["415-555-0134"])
    }

    /// The corpus is real history. Whatever this finds in it is what the user will see, so
    /// it is worth knowing that it is not finding a date on every other line.
    @Test func theCorpusYieldsNothingFromItsHeaders() {
        let document = Document(Corpus.text)
        for (index, line) in document.lines.enumerated() {
            guard case .dayHeader = line.kind else { continue }
            #expect(
                Highlighting.detections(inLine: line.raw, kind: line.kind).isEmpty,
                "line \(index): \(line.raw)"
            )
        }
    }

    // MARK: - Locating one from a document offset

    @Test func aDocumentOffsetFindsTheDetectionUnderIt() {
        let text = "monday 8/31/2026\n- call mom 415-555-0134\n- nothing here\n"
        let document = Document(text)
        let start = (text as NSString).range(of: "415-555-0134").location

        #expect(document.detection(atUTF16Offset: start)?.kind == .phoneNumber)
        #expect(document.detection(atUTF16Offset: start + 4)?.kind == .phoneNumber)
        // The caret sitting just past the end still counts: that is where a click at the
        // right-hand edge of the text lands.
        #expect(document.detection(atUTF16Offset: start + 12)?.kind == .phoneNumber)
        #expect(document.detection(atUTF16Offset: start - 2) == nil)
        #expect(document.detection(atUTF16Offset: 3) == nil)
    }

    @Test func anOffsetPastTheEndIsNotACrash() {
        let document = Document("- call 415-555-0134")
        #expect(document.detection(atUTF16Offset: 10_000) == nil)
        #expect(document.detection(atUTF16Offset: -1) == nil)
    }

    // MARK: - Styling

    @Test func aDetectionIsHighlightedAsSuch() {
        let raw = "- email jane@example.com"
        let roles = Highlighting.spans(forLine: raw).map(\.role)
        #expect(roles.contains(.detectedData))
    }

    /// Detection changes how the line is drawn and nothing else. The bytes are the bytes.
    @Test func detectionNeverTouchesTheText() {
        let text = "- call 415-555-0134 or jane@example.com or https://example.com\n"
        #expect(Document(text).serialized == text)
    }
}
