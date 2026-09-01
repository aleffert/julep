import Foundation

/// What the margin shows next to a line.
public enum GutterMark: Equatable, Sendable {
    /// An unresolved item: tap to move it into `done`.
    case openItem
    /// The line has a diagnostic. Tapping offers the fix, never applies it.
    case diagnostic(hasFix: Bool)

    public var isDiagnostic: Bool {
        if case .diagnostic = self { return true }
        return false
    }
}

extension Document {
    /// Marks for the whole document, keyed by line index.
    ///
    /// Diagnostics win over the done affordance on the same line: a line the app is unsure
    /// about should be resolved before it is acted on.
    public func gutterMarks(diagnostics: [Diagnostic]) -> [Int: GutterMark] {
        marks(diagnostics: diagnostics, blocks: blocks, lines: lines.indices)
    }

    /// The marks for one span of lines -- what the gutter draws beside the text on screen.
    ///
    /// Diagnostics and open items come back together because they are read off the same
    /// window of blocks, and the gutter has never wanted one without the other.
    public func gutterMarks(in range: Range<Int>) -> [Int: GutterMark] {
        marks(
            diagnostics: Diagnostics.analyze(self, lines: range),
            blocks: blocks(intersecting: range, margin: 0),
            lines: range
        )
    }

    private func marks(
        diagnostics: [Diagnostic], blocks: [Block], lines range: Range<Int>
    ) -> [Int: GutterMark] {
        var marks: [Int: GutterMark] = [:]

        for block in blocks {
            for section in block.sections where section.label != .done {
                for index in section.itemIndices where range.contains(index) {
                    marks[index] = .openItem
                }
            }
        }
        for diagnostic in diagnostics where range.contains(diagnostic.lineIndex) {
            marks[diagnostic.lineIndex] = .diagnostic(hasFix: diagnostic.fix != nil)
        }
        return marks
    }

    /// UTF-16 offset each line starts at, for mapping text positions back to lines.
    public var lineStartOffsets: [Int] {
        var offsets: [Int] = []
        offsets.reserveCapacity(lines.count)
        var running = 0
        for line in lines {
            offsets.append(running)
            running += line.utf16Length + 1  // + the newline
        }
        return offsets
    }

    /// The line containing a UTF-16 offset.
    public func lineIndex(atUTF16Offset offset: Int) -> Int? {
        lineIndex(atUTF16Offset: offset, in: lineStartOffsets)
    }
}
