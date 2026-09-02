import SwiftUI
import JulepKit

/// Presents versions that disagree, and lets the user pick.
///
/// Deliberately not automatic. The journal is the only copy of years of history, so the app
/// shows what is at stake and asks; "keep both" is offered first because it is the only
/// choice that cannot lose anything.
///
/// What is at stake is shown as a diff rather than as two previews of the file. A roll
/// prepends, so two versions of a journal are overwhelmingly identical and differ in a
/// handful of lines; printing both in full buries the answer to the only question this screen
/// exists to ask, which is what the other choice would cost.
struct ConflictView: View {
    @Bindable var workspace: Workspace

    /// Each conflicting version compared against this device's, by version id.
    ///
    /// Held rather than computed in `body`: a comparison walks the whole journal, and `body`
    /// runs whenever anything on this screen changes. Recomputed when the set of conflicts
    /// changes, which on this screen means once.
    @State private var comparisons: [String: VersionDiff.Comparison] = [:]

    var body: some View {
        List {
            Section {
                Text("This journal was edited in two places. Nothing has been changed yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(workspace.conflicts) { version in
                Section {
                    comparison(with: version)

                    Button("Keep both") {
                        resolve(.keepBoth(id: version.id))
                    }
                    Button("Use this version instead") {
                        resolve(.takeOther(id: version.id))
                    }
                } header: {
                    Text(header(version))
                }
            }

            Section {
                Button("Keep what is on this device", role: .destructive) {
                    resolve(.keepCurrent)
                }
            } footer: {
                Text("The other version will be discarded.")
            }
        }
        .navigationTitle("Two versions")
        .task(id: workspace.conflicts.map(\.id)) {
            let mine = workspace.journalText
            comparisons = workspace.conflicts.reduce(into: [:]) { result, version in
                result[version.id] = VersionDiff.compare(mine: mine, theirs: version.text)
            }
        }
        // The binding that presents this screen refuses to close while a conflict stands, so
        // an interactive dismissal would spring straight back. Saying so outright is clearer
        // than a sheet that appears to resist the gesture.
        .interactiveDismissDisabled()
    }

    private func header(_ version: ConflictingVersion) -> String {
        let device = version.deviceName ?? "Another device"
        guard let modified = version.modified else { return device }
        return "\(device) — \(modified.formatted(date: .abbreviated, time: .shortened))"
    }

    // MARK: - The difference

    @ViewBuilder
    private func comparison(with version: ConflictingVersion) -> some View {
        switch comparisons[version.id] {
        case .none:
            // The first frame, before `task` has run. Nothing to say yet, and the buttons
            // below are the part that matters.
            EmptyView()

        case .identical:
            Text("Both versions say exactly the same thing. Any choice is safe.")
                .font(.callout)
                .foregroundStyle(.secondary)

        case .tooDifferent(let mineOnly, let theirsOnly):
            VStack(alignment: .leading, spacing: 4) {
                Text("These versions have diverged too far to compare line by line.")
                Text("\(mineOnly) lines only here, \(theirsOnly) only on the other device.")
                    .foregroundStyle(.secondary)
                Text("\"Keep both\" is the only choice that keeps all of it.")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

        case .hunks(let hunks):
            legend(for: version)
            ForEach(Array(hunks.enumerated()), id: \.element.id) { index, hunk in
                if index > 0 {
                    gap(hunks[index - 1].end, hunk.start)
                }
                ForEach(hunk.rows) { row in
                    line(row, otherDevice: version.deviceName)
                }
            }
        }
    }

    private func legend(for version: ConflictingVersion) -> some View {
        HStack(spacing: 12) {
            Label("only here", systemImage: "minus")
                .foregroundStyle(Self.sideColor(for: .mine))
            Label("only on \(version.deviceName ?? "the other device")", systemImage: "plus")
                .foregroundStyle(Self.sideColor(for: .theirs))
        }
        .font(.caption2)
        .labelStyle(.titleAndIcon)
    }

    private func gap(_ from: Int, _ to: Int) -> some View {
        Text("⋯ \(to - from - 1) unchanged lines")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    /// One line of the comparison.
    ///
    /// The sign carries the meaning and the colour only reinforces it -- the same reason the
    /// editor underlines a line it cannot read instead of merely recolouring it. The line is
    /// monospaced because the journal's structure is made of leading spaces, and a
    /// proportional font hides the indentation that says what a line is.
    private func line(_ row: VersionDiff.Row, otherDevice: String?) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(Self.sign(for: row.side))
                .foregroundStyle(Self.sideColor(for: row.side))
            Text(row.text.isEmpty ? " " : row.text)
                .foregroundStyle(Self.textColor(for: row.side))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.caption, design: .monospaced))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(row, otherDevice: otherDevice))
    }

    private static func sign(for side: VersionDiff.Side) -> String {
        switch side {
        case .shared: " "
        case .mine: "−"
        case .theirs: "+"
        }
    }

    /// The sign's colour. Reinforcement only -- the sign says the same thing without it, so
    /// the screen still works for someone who cannot tell the two hues apart.
    private static func sideColor(for side: VersionDiff.Side) -> Color {
        switch side {
        case .shared: .secondary
        case .mine: .blue
        case .theirs: .orange
        }
    }

    /// Unchanged lines recede: they are context, not the decision.
    private static func textColor(for side: VersionDiff.Side) -> Color {
        switch side {
        case .shared: .secondary
        case .mine, .theirs: .primary
        }
    }

    private static func spoken(_ row: VersionDiff.Row, otherDevice: String?) -> String {
        switch row.side {
        case .shared: row.text
        case .mine: "Only here: \(row.text)"
        case .theirs: "Only on \(otherDevice ?? "the other device"): \(row.text)"
        }
    }

    private func resolve(_ resolution: ConflictResolution) {
        // No dismissal here. The screen is presented from `workspace.conflicts`, which is
        // re-derived from disk once the resolution lands, so it closes when the conflict is
        // genuinely gone and stays up when it is not.
        Task { await workspace.resolveConflicts(resolution) }
    }
}
