import Foundation

/// A line-by-line comparison of two versions of the same journal.
///
/// Only ever shown, never applied. The point is to answer one question before the user picks
/// a resolution -- *what would I lose?* -- which two side-by-side previews cannot, because a
/// roll prepends and months of identical history sit underneath the few lines that differ.
///
/// This device's version is the base, so a line that exists only here reads as a removal and
/// a line that exists only on the other device reads as an insertion. That is a presentation
/// choice, not a claim about which came first; neither version is the original.
public enum VersionDiff {
    /// Which version a line appears in.
    public enum Side: Equatable, Sendable {
        /// In both, and therefore not at stake.
        case shared
        /// Only in this device's version.
        case mine
        /// Only in the other device's version.
        case theirs
    }

    public struct Row: Equatable, Sendable, Identifiable {
        public let id: Int
        public let side: Side
        public let text: String
        /// Where this sits in this device's version, 1-based. A `theirs` row borrows the
        /// number of the line it would be inserted before, which is what orients it.
        public let line: Int
    }

    /// A run of differing lines with a little unchanged text either side.
    public struct Hunk: Equatable, Sendable, Identifiable {
        public let id: Int
        public let rows: [Row]
        /// First and last line of this hunk in this device's version, 1-based inclusive.
        public var start: Int { rows.first?.line ?? 1 }
        public var end: Int { rows.last?.line ?? 1 }
    }

    public enum Comparison: Equatable, Sendable {
        /// The same text on both sides. Possible: iCloud reports a conflict on metadata, not
        /// only on content.
        case identical
        case hunks([Hunk])
        /// Further apart than a diff can usefully show. Reported as counts rather than
        /// rendered, because a page of alternating lines tells the user nothing they can act
        /// on and is slower to draw than it is to read.
        case tooDifferent(mineOnly: Int, theirsOnly: Int)
    }

    /// Compares two versions.
    ///
    /// - Parameters:
    ///   - context: unchanged lines kept either side of each run of differences.
    ///   - limit: differing lines past which the two are reported as `tooDifferent`.
    public static func compare(
        mine: String,
        theirs: String,
        context: Int = 3,
        limit: Int = 200
    ) -> Comparison {
        let mineLines = mine.components(separatedBy: "\n")
        let theirLines = theirs.components(separatedBy: "\n")

        // Trimming the matching head and tail first is what keeps this cheap on a real
        // journal: the divergence is a handful of lines, and Myers is only asked about those
        // rather than about every day since the file was started.
        let prefix = commonPrefix(mineLines, theirLines)
        let suffix = commonSuffix(mineLines, theirLines, notBefore: prefix)
        let mineMiddle = mineLines[prefix..<(mineLines.count - suffix)]
        let theirMiddle = theirLines[prefix..<(theirLines.count - suffix)]
        if mineMiddle.isEmpty && theirMiddle.isEmpty { return .identical }

        let difference = Array(theirMiddle).difference(from: Array(mineMiddle))
        if difference.count > limit {
            return .tooDifferent(
                mineOnly: difference.removals.count,
                theirsOnly: difference.insertions.count
            )
        }

        var rows: [Row] = []
        for (offset, text) in mineLines.prefix(prefix).enumerated() {
            rows.append(Row(id: rows.count, side: .shared, text: text, line: offset + 1))
        }
        rows.append(contentsOf: align(
            mine: Array(mineMiddle),
            theirs: Array(theirMiddle),
            difference: difference,
            firstLine: prefix + 1,
            firstID: rows.count
        ))
        for (offset, text) in mineLines.suffix(suffix).enumerated() {
            rows.append(Row(
                id: rows.count,
                side: .shared,
                text: text,
                line: mineLines.count - suffix + offset + 1
            ))
        }

        return .hunks(group(rows, context: context))
    }

    // MARK: - Alignment

    /// Walks both versions at once, turning an edit script into rows in reading order.
    ///
    /// Removal offsets are positions in `mine` and insertion offsets are positions in
    /// `theirs`, so the two indices advance independently and only a shared line moves both.
    /// Removals are emitted before insertions at the same point, which is the order every
    /// diff has been read in for fifty years.
    private static func align(
        mine: [String],
        theirs: [String],
        difference: CollectionDifference<String>,
        firstLine: Int,
        firstID: Int
    ) -> [Row] {
        var removals: [Int: String] = [:]
        var insertions: [Int: String] = [:]
        for change in difference {
            switch change {
            case .remove(let offset, let element, _): removals[offset] = element
            case .insert(let offset, let element, _): insertions[offset] = element
            }
        }

        var rows: [Row] = []
        var mineIndex = 0
        var theirIndex = 0
        while mineIndex < mine.count || theirIndex < theirs.count {
            let line = firstLine + mineIndex
            let id = firstID + rows.count
            if let text = removals[mineIndex] {
                rows.append(Row(id: id, side: .mine, text: text, line: line))
                mineIndex += 1
            } else if let text = insertions[theirIndex] {
                rows.append(Row(id: id, side: .theirs, text: text, line: line))
                theirIndex += 1
            } else if mineIndex < mine.count, theirIndex < theirs.count {
                rows.append(Row(id: id, side: .shared, text: mine[mineIndex], line: line))
                mineIndex += 1
                theirIndex += 1
            } else {
                // Unreachable while the edit script matches the two versions it came from.
                // Advancing rather than trapping: a diff is a convenience, and refusing to
                // draw one is not worth taking down a screen the user needs to resolve a
                // conflict.
                mineIndex += 1
                theirIndex += 1
            }
        }
        return rows
    }

    // MARK: - Grouping

    /// Keeps the differing runs and `context` lines either side, dropping the rest.
    private static func group(_ rows: [Row], context: Int) -> [Hunk] {
        var ranges: [Range<Int>] = []
        for (offset, row) in rows.enumerated() where row.side != .shared {
            let lower = max(0, offset - context)
            let upper = min(rows.count, offset + context + 1)
            // Runs that touch are one hunk: two lines of context between two changes is a
            // gap marker announcing less than it costs to read.
            if let last = ranges.last, last.upperBound >= lower {
                ranges[ranges.count - 1] = last.lowerBound..<max(last.upperBound, upper)
            } else {
                ranges.append(lower..<upper)
            }
        }
        return ranges.enumerated().map { Hunk(id: $0.offset, rows: Array(rows[$0.element])) }
    }

    // MARK: - Trimming

    private static func commonPrefix(_ mine: [String], _ theirs: [String]) -> Int {
        var count = 0
        while count < mine.count, count < theirs.count, mine[count] == theirs[count] {
            count += 1
        }
        return count
    }

    private static func commonSuffix(
        _ mine: [String],
        _ theirs: [String],
        notBefore prefix: Int
    ) -> Int {
        var count = 0
        while count < mine.count - prefix,
              count < theirs.count - prefix,
              mine[mine.count - 1 - count] == theirs[theirs.count - 1 - count] {
            count += 1
        }
        return count
    }
}
