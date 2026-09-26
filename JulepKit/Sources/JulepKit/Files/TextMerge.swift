import Foundation

/// A three-way line merge of two sets of edits to the same journal.
///
/// Only ever applied where the base is genuinely the ancestor of both sides. That is true of
/// this process's own `lastWritten`, which is exactly what it last put on disk -- so a clean
/// merge against it is correct by construction rather than by luck. It is *not* true of an
/// iCloud conflict, where the other device's ancestor is not knowable: there a clean result is
/// offered as a resolution and applied only on acceptance. See `ConflictResolution.merge`.
///
/// Conservative by design. Anything it is not sure about comes back `conflicted`, which costs
/// the user a question; the opposite mistake costs them part of the only copy of their journal.
public enum TextMerge {
    public enum Outcome: Equatable, Sendable {
        /// Both sides' changes, combined. Neither side's edits are dropped.
        case merged(String)
        /// The two sides changed the same lines, and choosing between them is not the app's
        /// call to make.
        case conflicted
    }

    public static func merge(base: String, mine: String, theirs: String) -> Outcome {
        // The cheap answers first, and the only ones that hold when there is no real ancestor:
        // if a side did not move, the other side's version is the merge.
        if mine == theirs { return .merged(mine) }
        if base == mine { return .merged(theirs) }
        if base == theirs { return .merged(mine) }

        let baseLines = base.components(separatedBy: "\n")
        let mineHunks = hunks(base: baseLines, other: mine.components(separatedBy: "\n"))
        let theirHunks = hunks(base: baseLines, other: theirs.components(separatedBy: "\n"))

        var merged: [String] = []
        var index = 0
        var mineNext = 0
        var theirNext = 0

        while index < baseLines.count || mineNext < mineHunks.count || theirNext < theirHunks.count {
            let mineHunk = mineHunks[safe: mineNext].flatMap { $0.base.lowerBound == index ? $0 : nil }
            let theirHunk = theirHunks[safe: theirNext].flatMap { $0.base.lowerBound == index ? $0 : nil }

            switch (mineHunk, theirHunk) {
            case (nil, nil):
                // Unreachable: a hunk still pending cannot start before the current line.
                guard index < baseLines.count else { return .conflicted }
                merged.append(baseLines[index])
                index += 1

            case (let hunk?, nil):
                // A hunk starting inside the lines this one replaces is the other side editing
                // the same region, which is the one thing this cannot decide.
                guard theirHunks[safe: theirNext].map({ $0.base.lowerBound >= hunk.base.upperBound }) ?? true
                else { return .conflicted }
                merged += hunk.replacement
                index = hunk.base.upperBound
                mineNext += 1

            case (nil, let hunk?):
                guard mineHunks[safe: mineNext].map({ $0.base.lowerBound >= hunk.base.upperBound }) ?? true
                else { return .conflicted }
                merged += hunk.replacement
                index = hunk.base.upperBound
                theirNext += 1

            case (let mineHunk?, let theirHunk?):
                // Both changed this spot. Identical changes are agreement, not a conflict --
                // the same roll arriving twice is the ordinary way this happens.
                guard mineHunk == theirHunk else { return .conflicted }
                merged += mineHunk.replacement
                index = mineHunk.base.upperBound
                mineNext += 1
                theirNext += 1
            }
        }

        return .merged(merged.joined(separator: "\n"))
    }

    /// One contiguous change: the base lines it replaces, and what replaces them. A pure
    /// insertion has an empty range, a pure deletion an empty replacement.
    private struct Hunk: Equatable {
        let base: Range<Int>
        let replacement: [String]
    }

    /// Turns an edit script into replacements addressed in base coordinates.
    ///
    /// Removal offsets index `base` and insertion offsets index `other`, so the two walk
    /// independently and only an unchanged line advances both -- the same shape as
    /// `VersionDiff.align`, which reads the script for display rather than for application.
    private static func hunks(base: [String], other: [String]) -> [Hunk] {
        var removed: Set<Int> = []
        var inserted: [Int: String] = [:]
        for change in other.difference(from: base) {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, let element, _): inserted[offset] = element
            }
        }

        var hunks: [Hunk] = []
        var start: Int?
        var replacement: [String] = []
        var baseIndex = 0
        var otherIndex = 0

        func close(at end: Int) {
            guard let started = start else { return }
            hunks.append(Hunk(base: started..<end, replacement: replacement))
            start = nil
            replacement = []
        }

        while baseIndex < base.count || otherIndex < other.count {
            if removed.contains(baseIndex) {
                if start == nil { start = baseIndex }
                baseIndex += 1
            } else if let line = inserted[otherIndex] {
                if start == nil { start = baseIndex }
                replacement.append(line)
                otherIndex += 1
            } else if baseIndex < base.count, otherIndex < other.count {
                close(at: baseIndex)
                baseIndex += 1
                otherIndex += 1
            } else {
                break
            }
        }
        close(at: baseIndex)
        return hunks
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
