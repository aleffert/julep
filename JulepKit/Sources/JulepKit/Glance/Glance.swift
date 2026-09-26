import Foundation

/// What a home screen widget shows: the newest block's open items, and whether that block is
/// today's.
///
/// Derived here rather than in the widget so it is testable without a rendering target, and so
/// the widget process does nothing but read the file, derive this, and draw.
public struct Glance: Equatable, Sendable {
    /// The newest block's header. `nil` only for a journal with no block in it at all.
    public let header: DayHeader?

    /// Whether the newest block is today's.
    ///
    /// The widget has to say this rather than let it be inferred. The items below are the same
    /// either way, and a list of yesterday's leftovers presented as today's is the one thing a
    /// glance at the journal must not do.
    public let isCurrent: Bool

    /// The newest block's open items, in the order the file has them.
    ///
    /// The unlabeled section only: `done` is a record of what happened and `next` is a plan for
    /// the day after, and neither is what is still open now.
    public let items: [OpenItem]

    /// One open item, with the line it was read from.
    ///
    /// The line travels with the item so a tap can say which one it meant. It is a hint and not
    /// an identity -- the journal deliberately stores none -- so whoever acts on it checks that
    /// the line still says this before believing it.
    public struct OpenItem: Equatable, Sendable {
        public let lineIndex: Int
        public let item: Item

        public init(lineIndex: Int, item: Item) {
            self.lineIndex = lineIndex
            self.item = item
        }
    }

    /// Whether rolling would add anything, so the widget can offer the action exactly when it
    /// means something. See `Roll.isNeeded(document:today:)`.
    public let canRoll: Bool

    public init(header: DayHeader?, isCurrent: Bool, items: [OpenItem], canRoll: Bool) {
        self.header = header
        self.isCurrent = isCurrent
        self.items = items
        self.canRoll = canRoll
    }

    public static func of(document: Document, today: Date = NaturalDates.today()) -> Glance {
        let head = document.blocks.first
        let items = (head?.openSection?.itemIndices ?? []).compactMap { index -> OpenItem? in
            guard case .item(let item) = document.lines[index].kind else { return nil }
            return OpenItem(lineIndex: index, item: item)
        }
        return Glance(
            header: head?.header,
            isCurrent: head?.header.date == today,
            items: items,
            canRoll: Roll.isNeeded(document: document, today: today)
        )
    }
}
