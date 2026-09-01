import Foundation

extension Document {
    /// Every tag present in the journal, sorted. What `tag-entry` offers, so tags are picked
    /// from the ones already in use rather than typed with brackets by hand.
    /// Most recently used first.
    ///
    /// Blocks are newest-first, so first appearance in the file *is* recency. Alphabetical
    /// order would bury the two or three tags actually in use behind everything ever typed,
    /// and this list exists to be picked from quickly.
    public var tags: [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for line in lines {
            guard case .item(let item) = line.kind, let tag = item.tag else { continue }
            if seen.insert(tag.name).inserted { ordered.append(tag.name) }
        }
        return ordered
    }

    /// The handful worth offering in a menu.
    ///
    /// The corpus has nine tags across eight months and only two in regular use. A complete
    /// list is a scrolling menu of mostly-dead entries; the recent few plus a way to type a
    /// new one covers what actually happens.
    public func recentTags(limit: Int = 6) -> [String] {
        Array(tags.prefix(limit))
    }

    /// Moves the item on `lineIndex` into its block's `done` section, creating the section if
    /// the block does not have one yet.
    ///
    /// Returns `nil` when there is nothing to do -- the line is not an item, or it is already
    /// done -- so the caller can leave the file untouched rather than rewriting it identically.
    public func markingDone(lineIndex: Int) -> Document? {
        guard lines.indices.contains(lineIndex),
              case .item = lines[lineIndex].kind,
              let block = blocks.first(where: { $0.range.contains(lineIndex) }),
              block.section(.done)?.itemIndices.contains(lineIndex) != true
        else { return nil }

        let raw = lines[lineIndex].raw
        var updated = lines
        updated.remove(at: lineIndex)

        // Re-derive structure after the removal rather than adjusting indices by hand; the
        // block's header cannot have moved, since an item always sits below it.
        return Document(lines: updated)
            .insertingDone(raw, intoBlockAt: block.headerIndex)
    }

    /// Adds `raw` to the newest block's `done` section. What a decision recorded today goes
    /// into -- see `cancellingSchedule(of:)`.
    func insertingIntoNewestDoneSection(_ raw: String) -> Document? {
        guard let newest = blocks.first else { return nil }
        return insertingDone(raw, intoBlockAt: newest.headerIndex)
    }

    /// Puts `raw` in one block's `done` section, creating the section if it has none.
    ///
    /// The `done` section specifically, and not only because that is where finished things
    /// belong: roll carries the other sections forward, so a line placed anywhere else would
    /// follow the user around forever.
    private func insertingDone(_ raw: String, intoBlockAt headerIndex: Int) -> Document? {
        // Structure is re-derived rather than adjusted by hand; a caller may have removed a
        // line already, and a block's header cannot have moved because an item always sits
        // below it.
        guard let target = blocks.first(where: { $0.headerIndex == headerIndex })
        else { return nil }

        let insertion: (index: Int, lines: [String])
        if let done = target.section(.done) {
            let last = done.itemIndices.last ?? done.labelIndex
            insertion = ((last ?? target.headerIndex) + 1, [raw])
        } else if let nextLabel = target.section(.next)?.labelIndex {
            // done comes before next in the conventional order.
            insertion = (nextLabel, ["done", raw])
        } else {
            let lastContent = target.sections
                .compactMap { $0.itemIndices.last ?? $0.labelIndex }
                .max()
            insertion = ((lastContent ?? target.headerIndex) + 1, ["done", raw])
        }

        var updated = lines
        updated.insert(
            contentsOf: insertion.lines.map { Line(raw: $0, kind: Grammar.classify($0)) },
            at: insertion.index
        )
        return Document(lines: updated)
    }
}
