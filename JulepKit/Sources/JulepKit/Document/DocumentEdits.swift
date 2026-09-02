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
            .inserting(raw, into: .done, ofBlockAt: block.headerIndex)
    }

    /// Moves the item on `lineIndex` between its block's `done` section and its open one.
    ///
    /// `nil` when there is nothing to do -- the line is not an item, or sits in no block --
    /// so the caller can leave the file untouched rather than rewriting it identically.
    ///
    /// Reopening puts the item in the open section, never back in `next`. Nothing in the
    /// file records where a finished item came from, so the toggle is not quite an inverse:
    /// checking off something from `next` and immediately unchecking it moves it. Undo is
    /// the way back, not a second toggle.
    public func togglingDone(lineIndex: Int) -> Document? {
        guard lines.indices.contains(lineIndex),
              case .item = lines[lineIndex].kind,
              let block = blocks.first(where: { $0.range.contains(lineIndex) })
        else { return nil }

        guard block.section(.done)?.itemIndices.contains(lineIndex) == true else {
            return markingDone(lineIndex: lineIndex)
        }

        let raw = lines[lineIndex].raw
        var updated = lines
        updated.remove(at: lineIndex)
        // Structure re-derived after the removal, as in `markingDone`: the header cannot
        // have moved, because a done item always sits below it.
        return Document(lines: updated)
            .insertingOpen(raw, intoBlockAt: block.headerIndex)
    }

    /// Puts `raw` in one block's open section -- the unlabeled run under the header.
    private func insertingOpen(_ raw: String, intoBlockAt headerIndex: Int) -> Document? {
        guard let target = blocks.first(where: { $0.headerIndex == headerIndex })
        else { return nil }

        // After the open run if there is one; otherwise directly under the header, which is
        // where the open section begins when a block has only `done` and `next`.
        let index = (target.openSection?.itemIndices.last ?? target.headerIndex) + 1

        var updated = lines
        updated.insert(Line(raw: raw, kind: Grammar.classify(raw)), at: index)
        return Document(lines: updated)
    }

    /// Adds `raw` to the newest block's `done` section. What a decision recorded today goes
    /// into -- see `cancellingSchedule(of:)`.
    ///
    /// The `done` section specifically, and not only because that is where finished things
    /// belong: roll carries the other sections forward, so a line placed anywhere else would
    /// follow the user around forever.
    func insertingIntoNewestDoneSection(_ raw: String) -> Document? {
        guard let newest = blocks.first else { return nil }
        return inserting(raw, into: .done, ofBlockAt: newest.headerIndex)
    }

    /// Puts `raw` in one block's `label` section, creating the section if it has none.
    ///
    /// A section created here lands where `SectionLabel.conventionalOrder` says it goes:
    /// before the first section that ranks after it, and otherwise after everything the
    /// block already holds. Positioned off the sections' own lines rather than the block's
    /// range, which runs on through the blank line that separates one block from the next.
    private func inserting(
        _ raw: String, into label: SectionLabel, ofBlockAt headerIndex: Int
    ) -> Document? {
        // Structure is re-derived rather than adjusted by hand; a caller may have removed a
        // line already, and a block's header cannot have moved because an item always sits
        // below it.
        guard let target = blocks.first(where: { $0.headerIndex == headerIndex })
        else { return nil }

        let insertion: (index: Int, lines: [String])
        if let existing = target.section(label) {
            let last = existing.itemIndices.last ?? existing.labelIndex
            insertion = ((last ?? target.headerIndex) + 1, [raw])
        } else if let following = target.sections.first(where: {
            SectionLabel.rank(of: $0.label) > SectionLabel.rank(of: label)
        })?.labelIndex {
            insertion = (following, [label.rawValue, raw])
        } else {
            let lastContent = target.sections
                .compactMap { $0.itemIndices.last ?? $0.labelIndex }
                .max()
            insertion = ((lastContent ?? target.headerIndex) + 1, [label.rawValue, raw])
        }

        var updated = lines
        updated.insert(
            contentsOf: insertion.lines.map { Line(raw: $0, kind: Grammar.classify($0)) },
            at: insertion.index
        )
        return Document(lines: updated)
    }

    /// Files an item deferred to the day after its own block into that block's `next`
    /// section, dropping the annotation.
    ///
    /// A one-day deferral is what `next` already means, said the long way round: an
    /// annotation to write, an occurrence to compute, and a line that disappears out of the
    /// block being written to reappear in the one after it. Filing it says the same thing in
    /// the file the user is looking at, and costs nothing to undo or re-read. It is also how
    /// `next` gets an inline entry point -- on iOS the `@schedule(` picker is the quick way
    /// to file something, and there was no equivalent for putting an item under `next`.
    ///
    /// `nil` where it does not apply, so the caller can leave the line as written: a line
    /// that is not an annotated item, an undated block, an argument that is not the day
    /// after that block, or an item already sitting in `done` or `next` -- there is nothing
    /// to move, and a `done` item is not waiting on anything.
    public func filingDeferralIntoNext(lineIndex: Int) -> Document? {
        guard lines.indices.contains(lineIndex),
              case .item(let item) = lines[lineIndex].kind,
              let annotation = item.annotation,
              let block = blocks.first(where: { $0.range.contains(lineIndex) }),
              let blockDate = block.header.date,
              block.openSection?.itemIndices.contains(lineIndex) == true,
              let argument = NaturalDates.parse(annotation.argument, relativeTo: blockDate)
        else { return nil }

        let due: Date
        switch argument {
        case .date(let date):
            due = date
        case .recurrence:
            // A repeat is never filed. The annotation *is* the rule -- it is read back out
            // of this line every time the schedule is derived -- so dropping it would stop
            // the repeat rather than restate it. `every day` is the near miss: its first
            // occurrence is the day after, and its second is the reason this returns.
            return nil
        }
        guard due == NaturalDates.day(1, after: blockDate) else { return nil }

        // Nothing but the annotation on the line: there would be no item left to file.
        let text = item.textWithoutAnnotation
        guard !text.isEmpty else { return nil }

        var updated = lines
        updated.remove(at: lineIndex)
        return Document(lines: updated)
            .inserting(Grammar.itemMarker + text, into: .next, ofBlockAt: block.headerIndex)
    }
}
