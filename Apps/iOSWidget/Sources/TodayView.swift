import JulepKit
import SwiftUI
import WidgetKit

/// The editor's own tag colour, so a tag reads the same on the home screen as it does in the
/// journal. The size passed here is immaterial -- only the colour is taken.
private let tagColor = Color(Theme.standard(size: 13).tagColor)

struct TodayView: View {
    let reading: JournalAccess.Reading

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch reading {
        case .glance(let glance):
            glanceView(glance)
        case .unavailable:
            unavailableView
        }
    }

    private func glanceView(_ glance: Glance) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Only when it says something. A widget on a home screen is obviously about now, so
            // a "Today" label spends a line of the little space there is restating that. The
            // header earns its place exactly when the newest block is *not* today's.
            if glance.canRoll { header(glance) }
            items(glance)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Header

    /// Whose day the list below belongs to, and the roll that makes it today's. On screen only
    /// when those are different days.
    private func header(_ glance: Glance) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            // The items below are real either way, but they are a previous day's leftovers
            // rather than a list anyone has looked at today, and the date is what says so.
            Text(glance.header?.displayRendered ?? "Nothing written yet")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Button(intent: RollIntent()) {
                Label("Roll", systemImage: "arrow.turn.down.right")
                    .labelStyle(.iconOnly)
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Items

    @ViewBuilder
    private func items(_ glance: Glance) -> some View {
        if glance.items.isEmpty {
            Text(glance.header == nil ? "Roll to start the first block" : "Nothing open")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(glance.items.prefix(limit), id: \.lineIndex) { open in
                ItemRow(open: open)
            }
            let hidden = glance.items.count - limit
            if hidden > 0 {
                Text("+\(hidden) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// How many items fit. A widget does not scroll, so anything past this is counted instead of
    /// drawn -- which is still honest about how much is open.
    private var limit: Int {
        switch family {
        case .systemSmall: 3
        case .systemMedium: 4
        case .systemLarge: 11
        default: 4
        }
    }

    // MARK: - Unavailable

    /// Its own state, never an empty list. See `JournalAccess.Reading`.
    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.secondary)
            Text("Can't see the journal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct ItemRow: View {
    let open: Glance.OpenItem

    private var item: Item { open.item }

    /// The margin's ring rather than the file's `- `. The marker is load-bearing in the editor,
    /// where it is what makes a line an item and is two characters the user types and deletes;
    /// here every row is an item already, so it distinguishes nothing. The ring does something
    /// the dash cannot, which is take the tap.
    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Button(intent: MarkDoneIntent(lineIndex: open.lineIndex, text: item.text)) {
                // A hollow ring, not a checkbox: nothing is checked off without a tap. Drawn
                // smaller than the margin's, which sits beside body text rather than a caption.
                //
                // The padding is the tap target, not the look. A ring this size is well under
                // what a finger wants, and a widget row has no room to make the ring itself
                // bigger.
                Circle()
                    .strokeBorder(.tertiary, lineWidth: 1.2)
                    .frame(width: 10, height: 10)
                    .padding(4)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
        // The ring's tap padding would otherwise space the rows further apart than the text
        // wants; taken back here so the list reads as a list.
        .padding(.vertical, -4)
    }

    /// The item exactly as the file writes it, brackets and all, with the tag coloured.
    ///
    /// Only the tag's *length* is taken from its span. `Tag.span` is anchored to the raw line so
    /// the editor can attach attributes to it, which means it counts the `- ` marker and any
    /// leading whitespace -- and this renders `item.text`, which begins after them. A tag is only
    /// a tag at the very start of that text, so its location here is zero by construction.
    private var text: AttributedString {
        guard let tag = item.tag,
              let span = Range(NSRange(location: 0, length: tag.span.length), in: item.text)
        else { return AttributedString(item.text) }
        var tagged = AttributedString(item.text[span])
        tagged.foregroundColor = tagColor
        return tagged + AttributedString(item.text[span.upperBound...])
    }
}
