import SwiftUI
import JulepKit

/// Presents versions that disagree, and lets the user pick.
///
/// Deliberately not automatic. The journal is the only copy of years of history, so the app
/// shows both sides and asks; "keep both" is offered first because it is the only choice that
/// cannot lose anything.
struct ConflictView: View {
    @Bindable var workspace: Workspace
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text("This journal was edited in two places. Nothing has been changed yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(workspace.conflicts) { version in
                Section {
                    Text(preview(version.text))
                        .font(.caption)
                        .lineLimit(8)

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
    }

    private func header(_ version: ConflictingVersion) -> String {
        let device = version.deviceName ?? "Another device"
        guard let modified = version.modified else { return device }
        return "\(device) — \(modified.formatted(date: .abbreviated, time: .shortened))"
    }

    /// The head of the file is where a roll lands, so it is the part most likely to differ.
    private func preview(_ text: String) -> String {
        text.components(separatedBy: "\n").prefix(8).joined(separator: "\n")
    }

    private func resolve(_ resolution: ConflictResolution) {
        Task {
            await workspace.resolveConflicts(resolution)
            dismiss()
        }
    }
}
