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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    /// Whose day the list below belongs to, and the roll that makes it today's. On screen only
    /// when those are different days.
    private func header(_ glance: Glance) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            // The items below are real either way, but they are a previous day's leftovers
            // rather than a list anyone has looked at today, and the date is what says so.
            Text(title(glance))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Button(intent: RollIntent()) {
                Label("Roll", systemImage: "arrow.turn.down.right")
                    .labelStyle(.iconOnly)
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
    }

    private func title(_ glance: Glance) -> String {
        guard let header = glance.header else { return "Nothing written yet" }
        switch family {
        case .systemSmall:
            // 158 points cannot hold "Sunday 8/30/2026" beside the roll button; the year is
            // what gives way, rather than the date truncating part way through it.
            return header.displayRenderedWithoutYear
        default:
            return header.displayRendered
        }
    }

    // MARK: - Items

    @ViewBuilder
    private func items(_ glance: Glance) -> some View {
        if glance.items.isEmpty {
            Text(glance.header == nil ? "Roll to start the first block" : "Nothing open")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            // How many items fit is a question only the layout can answer. Asked rather than
            // assumed: a count per widget size is right at exactly one text size, and a widget
            // follows whatever the reader has chosen -- so a number tuned by eye goes wrong for
            // anyone who has moved theirs, and goes wrong again the next time the font changes
            // here. The candidates run longest first, so the ordinary day, where everything
            // fits, is answered by the first one.
            ViewThatFits(in: .vertical) {
                ForEach(candidateCounts(for: glance.items), id: \.self) { count in
                    list(glance.items, showing: count)
                }
            }
        }
    }

    private func list(_ items: [Glance.OpenItem], showing count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.prefix(count), id: \.lineIndex) { open in
                ItemRow(open: open)
            }
            // Part of the candidate, not an afterthought: whether this line is there changes
            // the height, so a candidate measured without it would claim to fit and then not.
            if count < items.count {
                Text("+\(items.count - count) more")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Item counts to offer the layout, longest first.
    ///
    /// The ceiling bounds the work rather than the layout: no widget is tall enough to draw
    /// this many rows at any text size, so it never decides what is shown -- it only stops a
    /// journal with two hundred open items from being measured two hundred ways.
    private func candidateCounts(for items: [Glance.OpenItem]) -> [Int] {
        Array((1...min(items.count, 20)).reversed())
    }

    // MARK: - Unavailable

    /// Its own state, never an empty list. See `JournalAccess.Reading`.
    private var unavailableView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.secondary)
            Text("Can't see the journal")
                .font(.subheadline)
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
                // A hollow ring, not a checkbox: nothing is checked off without a tap. The
                // margin's own size and stroke, so it reads as the same affordance.
                //
                // The padding is the tap target, not the look. A ring this size is well under
                // what a finger wants, and a widget row has no room to make the ring itself
                // bigger.
                Circle()
                    .strokeBorder(.tertiary, lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                    .padding(5)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Text(text)
                .font(.subheadline)
                .lineLimit(1)
        }
        // The ring's tap padding would otherwise space the rows further apart than the text
        // wants; taken back here so the list reads as a list.
        .padding(.vertical, -5)
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
