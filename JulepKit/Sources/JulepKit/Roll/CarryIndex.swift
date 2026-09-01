import Foundation

/// An item that has survived several rolls without being resolved.
public struct CarriedItem: Equatable, Sendable {
    public var text: String
    /// Consecutive blocks, newest first, carrying this text unresolved.
    public var streak: Int
    /// Index into `Document.blocks` of the newest block in the run.
    public var newestBlockIndex: Int

    public init(text: String, streak: Int, newestBlockIndex: Int) {
        self.text = text
        self.streak = streak
        self.newestBlockIndex = newestBlockIndex
    }
}

/// Recovers carry counts by matching item text across adjacent blocks.
///
/// Roll copies item text verbatim, so an item carried forward is textually identical in every
/// block it appears in. That is enough to recover "this has been carried eleven times" without
/// storing any per-item identity -- which is the signal that keeping text as the source of
/// truth appeared to cost, handed back.
///
/// Built once and queried many times: computing block structure per item would be quadratic
/// over a journal that only grows.
public struct CarryIndex: Sendable {
    /// Unresolved item text per block, in file order (newest first). An item in `done` has
    /// been resolved, so it is absent here and ends the run.
    private let unresolvedByBlock: [Set<String>]

    public init(_ document: Document) {
        unresolvedByBlock = document.blocks.map { block in
            Set(
                block.sections
                    .filter { $0.label != .done }
                    .flatMap(\.itemIndices)
                    .compactMap { index in
                        guard case .item(let item) = document.lines[index].kind else { return nil }
                        return item.text
                    }
            )
        }
    }

    public var blockCount: Int { unresolvedByBlock.count }

    /// How many consecutive blocks, starting at `blockIndex` and walking back into older
    /// history, carry this text unresolved. Zero if the block does not carry it at all.
    public func streak(of text: String, from blockIndex: Int) -> Int {
        var count = 0
        var index = blockIndex
        while index < unresolvedByBlock.count, unresolvedByBlock[index].contains(text) {
            count += 1
            index += 1
        }
        return count
    }

    /// Every item whose longest unbroken run reaches `minimum`, longest first.
    ///
    /// This is what `carry-nudge` reads: an item that keeps being copied forward is a
    /// candidate for `@schedule`, because copying has become cheaper than deciding.
    public func longestRuns(minimum: Int = 2) -> [CarriedItem] {
        var longest: [String: CarriedItem] = [:]
        for blockIndex in unresolvedByBlock.indices {
            for text in unresolvedByBlock[blockIndex] {
                // Only start counting at the newest block of a run, so each run is seen once.
                if blockIndex > 0, unresolvedByBlock[blockIndex - 1].contains(text) { continue }
                let streak = streak(of: text, from: blockIndex)
                guard streak >= minimum else { continue }
                if let existing = longest[text], existing.streak >= streak { continue }
                longest[text] = CarriedItem(
                    text: text, streak: streak, newestBlockIndex: blockIndex
                )
            }
        }
        return longest.values.sorted {
            $0.streak != $1.streak ? $0.streak > $1.streak : $0.text < $1.text
        }
    }
}
