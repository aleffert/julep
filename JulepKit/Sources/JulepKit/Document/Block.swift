import Foundation

/// A run of lines within a block sharing one section label.
///
/// A `label` of `nil` is the unlabeled open section that sits directly under the header.
/// All three sections are optional, and their order is not fixed.
public struct Section: Equatable, Sendable {
    public var label: SectionLabel?
    /// Index of the label line itself, or `nil` for the unlabeled open section.
    public var labelIndex: Int?
    /// Indices into `Document.lines` of this section's item lines.
    public var itemIndices: [Int]

    public init(label: SectionLabel?, labelIndex: Int?, itemIndices: [Int]) {
        self.label = label
        self.labelIndex = labelIndex
        self.itemIndices = itemIndices
    }
}

/// One dated block: a header line and everything under it up to the next header.
public struct Block: Equatable, Sendable {
    public var headerIndex: Int
    public var header: DayHeader
    /// Every line from the header up to (not including) the next block's header.
    public var range: Range<Int>
    public var sections: [Section]
    /// The `delta N days` written above this header, if any.
    ///
    /// A delta sits physically above the header of the *older* block and describes the gap
    /// up to the newer block above it. It is often absent, and the corpus shows it is
    /// sometimes wrong -- but when it disagrees with the numeric date, it is the date that
    /// is usually at fault.
    public var deltaAbove: Int?
    /// Index of that delta line, so a fix-it can rewrite it.
    public var deltaAboveIndex: Int?

    public var openSection: Section? { sections.first { $0.label == nil } }
    public func section(_ label: SectionLabel) -> Section? {
        sections.first { $0.label == label }
    }
}

extension Document {
    /// Blocks in file order, which is newest first.
    public var blocks: [Block] {
        let headerIndices = lines.indices.filter { isHeader($0) }
        return blocks(headerIndices: headerIndices, lastEnd: lines.count)
    }

    /// The blocks whose lines fall in `range`, widened by `margin` blocks on each side.
    ///
    /// Walked outwards from the range rather than indexed off the whole journal. What asks
    /// this question is the gutter, about a screenful -- and a screenful is a handful of
    /// blocks however many years are behind it, so answering should cost a handful of blocks
    /// too.
    ///
    /// The margin is there because a header's diagnostics are not purely local: the deltas
    /// above and below are evidence about its date. One block either side is as far as the
    /// analysis ever reaches, which is why one is as far as this widens.
    public func blocks(intersecting range: Range<Int>, margin: Int = 1) -> [Block] {
        guard !lines.isEmpty else { return [] }
        let low = min(max(range.lowerBound, 0), lines.count)
        let high = min(max(range.upperBound, low), lines.count)

        // The block `low` sits inside -- or, if it sits above the first header, that one.
        guard var cursor = previousHeader(before: low + 1) ?? nextHeader(after: low - 1)
        else { return [] }
        for _ in 0..<margin {
            guard let earlier = previousHeader(before: cursor) else { break }
            cursor = earlier
        }

        var headerIndices: [Int] = []
        var past = 0
        var next: Int? = cursor
        while let current = next {
            if current >= high {
                past += 1
                if past > margin { break }
            }
            headerIndices.append(current)
            next = nextHeader(after: current)
        }
        guard let last = headerIndices.last else { return [] }
        return blocks(headerIndices: headerIndices, lastEnd: nextHeader(after: last) ?? lines.count)
    }

    private func blocks(headerIndices: [Int], lastEnd: Int) -> [Block] {
        headerIndices.enumerated().map { position, headerIndex in
            guard case let .dayHeader(header) = lines[headerIndex].kind else {
                preconditionFailure("header index does not point at a header")
            }
            let end = position + 1 < headerIndices.count ? headerIndices[position + 1] : lastEnd
            let (delta, deltaIndex) = deltaAbove(headerIndex: headerIndex)
            return Block(
                headerIndex: headerIndex,
                header: header,
                range: headerIndex..<end,
                sections: sections(from: headerIndex + 1, to: end),
                deltaAbove: delta,
                deltaAboveIndex: deltaIndex
            )
        }
    }

    private func isHeader(_ index: Int) -> Bool {
        if case .dayHeader = lines[index].kind { return true }
        return false
    }

    /// The nearest header strictly above `index`.
    private func previousHeader(before index: Int) -> Int? {
        var cursor = min(index, lines.count) - 1
        while cursor >= 0 {
            if isHeader(cursor) { return cursor }
            cursor -= 1
        }
        return nil
    }

    /// The nearest header strictly below `index`.
    private func nextHeader(after index: Int) -> Int? {
        var cursor = max(index, -1) + 1
        while cursor < lines.count {
            if isHeader(cursor) { return cursor }
            cursor += 1
        }
        return nil
    }

    /// Walks back over blank lines to find the delta belonging to this header.
    private func deltaAbove(headerIndex: Int) -> (Int?, Int?) {
        var cursor = headerIndex - 1
        while cursor >= 0 {
            switch lines[cursor].kind {
            case .blank:
                cursor -= 1
            case .delta(let days):
                return (days, cursor)
            default:
                return (nil, nil)
            }
        }
        return (nil, nil)
    }

    private func sections(from start: Int, to end: Int) -> [Section] {
        var sections: [Section] = []
        var label: SectionLabel?
        var labelIndex: Int?
        var itemIndices: [Int] = []

        func flush() {
            // The unlabeled open section only exists if it actually holds items;
            // a block whose header is followed straight by `done` has no open section.
            guard label != nil || !itemIndices.isEmpty else { return }
            sections.append(Section(label: label, labelIndex: labelIndex, itemIndices: itemIndices))
        }

        for index in start..<end {
            switch lines[index].kind {
            case .sectionLabel(let found):
                flush()
                label = found
                labelIndex = index
                itemIndices = []
            case .item:
                itemIndices.append(index)
            case .dayHeader, .delta, .blank, .unknown:
                break
            }
        }
        flush()
        return sections
    }
}
