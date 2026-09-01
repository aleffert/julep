import Foundation

/// Something inside an item that can be acted on: a phone number, an email address, a link.
///
/// Found rather than stored. The journal holds plain text and keeps holding plain text --
/// nothing here reaches `Line.raw`, so detection cannot alter a byte of the file. That is
/// what makes it safe to do at all in an app whose whole premise is not touching what was
/// written.
public struct Detection: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case phoneNumber
        case emailAddress
        case webLink
    }

    public var kind: Kind
    /// Where it sits in the line, in that line's own UTF-16 coordinates.
    public var span: Span
    /// The characters as written, which is what a menu should name it by.
    public var text: String
    /// Where acting on it goes.
    public var url: URL

    public init(kind: Kind, span: Span, text: String, url: URL) {
        self.kind = kind
        self.span = span
        self.text = text
        self.url = url
    }

    /// What to call the action, in the user's own words rather than the detector's.
    public var actionTitle: String {
        switch kind {
        case .phoneNumber: "Call \(text)"
        case .emailAddress: "Email \(text)"
        case .webLink: "Open \(text)"
        }
    }
}

extension Highlighting {
    // Built once and only read, like `NaturalDates.detector`: `NSDataDetector` is
    // `Sendable` -- it inherits `NSRegularExpression`'s thread safety -- and expensive
    // enough to construct that sharing one is worth it.
    private static let detector = try! NSDataDetector(
        types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue
            | NSTextCheckingResult.CheckingType.link.rawValue
    )

    /// What can be acted on in one line.
    ///
    /// Only inside an item's own text, and never inside its tag or annotation. A header is
    /// `monday 8/31/2026` and an annotation is `@schedule(9/8/2026)`; run a phone and link
    /// detector across those and it finds things that are not phone numbers or links. The
    /// grammar already knows which characters are prose and which are structure, so the
    /// detector is only ever shown the prose.
    public static func detections(inLine raw: String, kind: LineKind) -> [Detection] {
        guard case .item(let item) = kind, let marker = markerSpan(of: raw) else { return [] }

        let content = contentSpan(of: raw)
        let start = marker.location + marker.length
        let end = content.location + content.length
        guard end > start else { return [] }

        // The structural parts of the item, which the detector's findings must not overlap.
        let structure = [item.tag?.span, item.annotation?.span].compactMap { span in
            span.map { NSRange(location: $0.location, length: $0.length) }
        }

        let region = NSRange(location: start, length: end - start)
        let text = raw as NSString
        guard couldHoldData(text, in: region) else { return [] }

        return detector.matches(in: raw, options: [], range: region).compactMap { match in
            guard !structure.contains(where: { NSIntersectionRange($0, match.range).length > 0 })
            else { return nil }
            guard let (kind, url) = interpret(match) else { return nil }
            return Detection(
                kind: kind,
                span: Span(location: match.range.location, length: match.range.length),
                text: text.substring(with: match.range),
                url: url
            )
        }
    }

    /// Whether it is worth running the detector at all.
    ///
    /// It costs around ten microseconds a line even when it finds nothing, and the
    /// highlighter runs once per paragraph laid out. Nothing these three types can match
    /// exists in a line without a digit, an `@`, a dot or a colon: a phone number is made of
    /// digits, an address needs its `@`, and a link needs a host with a dot in it. So most of
    /// a journal never reaches the detector.
    private static func couldHoldData(_ text: NSString, in region: NSRange) -> Bool {
        for index in region.location..<NSMaxRange(region) {
            switch text.character(at: index) {
            case 0x40, 0x2E, 0x3A: return true  // @ . :
            case 0x30...0x39: return true  // 0-9
            default: continue
            }
        }
        return false
    }

    private static func interpret(_ match: NSTextCheckingResult) -> (Detection.Kind, URL)? {
        switch match.resultType {
        case .phoneNumber:
            guard let number = match.phoneNumber else { return nil }
            // `tel:` takes digits and a leading `+`; the spacing and punctuation people
            // write numbers with is for reading, not for dialling.
            let dialled = number.filter { $0.isNumber || $0 == "+" }
            guard !dialled.isEmpty, let url = URL(string: "tel:\(dialled)") else { return nil }
            return (.phoneNumber, url)
        case .link:
            guard let url = match.url else { return nil }
            return (url.scheme == "mailto" ? .emailAddress : .webLink, url)
        default:
            return nil
        }
    }
}

extension Document {
    /// What can be acted on at a UTF-16 offset into the whole journal, if anything.
    ///
    /// The offset is document-wide -- what a click or a caret reports -- while the returned
    /// `span` is in its own line's coordinates, because that is where the grammar works.
    public func detection(atUTF16Offset offset: Int) -> Detection? {
        let offsets = lineStartOffsets
        guard let index = lineIndex(atUTF16Offset: offset, in: offsets) else { return nil }
        let line = lines[index]
        let local = offset - offsets[index]
        return Highlighting.detections(inLine: line.raw, kind: line.kind).first {
            local >= $0.span.location && local <= $0.span.location + $0.span.length
        }
    }
}
