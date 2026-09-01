import Foundation

extension Document {
    /// The UTF-16 length `serialized` would have, without building it.
    ///
    /// Cheap enough to check on every edit, which is what makes it useful as a canary: the
    /// editor's text storage and this document are two views of one buffer, and a length that
    /// has drifted means the splice missed something. See `Document.replaceCharacters`.
    public var utf16Length: Int {
        guard !lines.isEmpty else { return 0 }
        return lines.reduce(lines.count - 1) { $0 + $1.utf16Length }
    }

    /// Applies a UTF-16 range replacement, reclassifying only the lines it touches.
    ///
    /// This is what lets the document be the journal's source of truth rather than a view
    /// recomputed from a string. Classification is the expensive part of parsing, and an edit
    /// can only change the classification of the lines it actually spans -- everything above
    /// and below keeps the `kind` it already had. Eight years of history therefore costs
    /// nothing per keystroke, where a full reparse cost all of it.
    ///
    /// Losslessness is unaffected: the spliced lines store their new `raw` verbatim, exactly
    /// as `init(_:)` would have.
    ///
    /// `range` is in the coordinates of the text *before* the edit, matching what a text
    /// view's change notification reports.
    public mutating func replaceCharacters(in range: NSRange, with replacement: String) {
        guard !lines.isEmpty else {
            self = Document(replacement)
            return
        }

        let offsets = lineStartOffsets
        // From the offsets already in hand, rather than a second walk over the lines.
        let total = offsets[offsets.count - 1] + lines[lines.count - 1].utf16Length
        let start = min(max(range.location, 0), total)
        let end = min(max(range.location + range.length, start), total)

        let first = lineIndex(atUTF16Offset: start, in: offsets) ?? 0
        let last = lineIndex(atUTF16Offset: end, in: offsets) ?? lines.count - 1

        // The surviving halves of the edge lines. Everything between them is replaced.
        let head = prefix(ofLine: first, upToUTF16Offset: start - offsets[first])
        let tail = suffix(ofLine: last, fromUTF16Offset: end - offsets[last])

        let spliced = (head + replacement + tail)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { raw -> Line in
                let raw = String(raw)
                return Line(raw: raw, kind: Grammar.classify(raw))
            }
        lines.replaceSubrange(first...last, with: spliced)
    }

    private func prefix(ofLine index: Int, upToUTF16Offset offset: Int) -> String {
        let utf16 = Array(lines[index].raw.utf16)
        return String(decoding: utf16[0..<min(max(offset, 0), utf16.count)], as: UTF16.self)
    }

    private func suffix(ofLine index: Int, fromUTF16Offset offset: Int) -> String {
        let utf16 = Array(lines[index].raw.utf16)
        return String(decoding: utf16[min(max(offset, 0), utf16.count)...], as: UTF16.self)
    }

    /// `lineIndex(atUTF16Offset:)` against offsets the caller already has, so a splice does
    /// not walk the document twice.
    func lineIndex(atUTF16Offset offset: Int, in offsets: [Int]) -> Int? {
        guard !offsets.isEmpty, offset >= 0 else { return nil }
        var low = 0
        var high = offsets.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if offsets[middle] <= offset { low = middle } else { high = middle - 1 }
        }
        return low
    }
}
