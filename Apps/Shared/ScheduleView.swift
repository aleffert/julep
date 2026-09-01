import SwiftUI
import JulepKit

/// Everything deferred, and when it comes back.
///
/// The point is verifiability: pushing something out three months should be checkable rather
/// than an act of faith. Overdue items sort first, because those are the ones the next roll
/// will put in front of you.
///
/// Every row is read out of the journal's own annotations, so there is no distinction any
/// more between something "filed" and something merely written down -- editing or deleting an
/// annotated line changes this list immediately, because the line is the only record there is.
struct ScheduleView: View {
    @Bindable var workspace: Workspace
    var today: Date = NaturalDates.today()

    @Environment(\.dismiss) private var dismiss

    private struct Entry: Identifiable {
        let item: ScheduledItem
        let due: Date
        var id: String { item.text }
    }

    private var entries: [Entry] {
        workspace.document.upcomingSchedules(asOf: today)
            .map { Entry(item: $0.item, due: $0.due) }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Nothing scheduled",
                    systemImage: "calendar",
                    description: Text("Items pushed out with @schedule(…) appear here.")
                )
            }
            ForEach(entries) { entry in
                ScheduleRow(entry: entry, today: today) {
                    remove(entry)
                }
            }
            // Swipe on iOS, in addition to the button every row carries. `onDelete` alone
            // offers nothing at all on macOS, which left an item impossible to remove.
            .onDelete { offsets in
                for offset in offsets { remove(entries[offset]) }
            }
        }
        .navigationTitle("Schedule")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("schedule.done")
            }
        }
    }

    /// Ends a deferral by recording that decision in today's block.
    ///
    /// Nothing is deleted, because there is nothing to delete: the deferral is an annotation
    /// in a block roll will never rewrite. Removing it here writes `@schedule(done)` against
    /// the same item, which supersedes the old annotation -- so the journal shows both that
    /// the repeat existed and that it was stopped.
    private func remove(_ entry: Entry) {
        guard let updated = workspace.document.cancellingSchedule(of: entry.item.text) else {
            return
        }
        workspace.replaceJournal(with: updated.serialized)
    }

    private struct ScheduleRow: View {
        let entry: Entry
        let today: Date
        var onRemove: () -> Void

        private var isDue: Bool { entry.due <= today }

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.item.text)
                        .font(.body)
                    HStack(spacing: 6) {
                        Image(systemName: entry.item.rule == nil ? "calendar" : "repeat")
                            .font(.caption2)
                        Text(detail)
                            .font(.caption)
                    }
                    .foregroundStyle(isDue ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                }
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Stop this schedule")
                .accessibilityLabel("Remove \(entry.item.text)")
                .accessibilityIdentifier("schedule.remove.\(entry.item.text)")
            }
            .padding(.vertical, 2)
        }

        private var detail: String {
            let when = isDue ? "Due now" : "Due \(NaturalDates.canonical(entry.due))"
            guard let rule = entry.item.rule else { return when }
            return "\(rule.capitalizedFirst) — \(when.lowercasedFirst)"
        }
    }
}
