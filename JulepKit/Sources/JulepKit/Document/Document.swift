import Foundation

/// The journal, as lines.
///
/// The document is lossless by construction: it stores every line's raw text, and
/// `serialized` is just those lines rejoined. A round trip is byte-identical unless a
/// line was deliberately edited, so the app cannot corrupt the file by parsing it.
///
/// Block and section structure is a computed view over `lines` (see `blocks`), never the
/// storage.
public struct Document: Equatable, Sendable {
    public var lines: [Line]

    public init(_ text: String) {
        lines = text.split(separator: "\n", omittingEmptySubsequences: false).map {
            let raw = String($0)
            return Line(raw: raw, kind: Grammar.classify(raw))
        }
    }

    public init(lines: [Line]) {
        self.lines = lines
    }

    /// The file's exact bytes. This reads `raw` only -- no classification participates,
    /// which is what makes losslessness a property of the type rather than of discipline.
    public var serialized: String {
        lines.map(\.raw).joined(separator: "\n")
    }

    /// Replaces one line, reclassifying it from its new text.
    public mutating func replaceLine(at index: Int, with raw: String) {
        lines[index] = Line(raw: raw, kind: Grammar.classify(raw))
    }
}
