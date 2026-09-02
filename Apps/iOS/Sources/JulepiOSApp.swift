import SwiftUI
import JulepKit

@main
struct JulepiOSApp: App {
    init() { ContainerDiagnostic.runIfRequested() }

    var body: some Scene {
        WindowGroup {
            JournalView()
        }
    }
}

struct JournalView: View {
    @State private var workspace = Workspace()
    @State private var offeredFix: OfferedFix?
    @State private var isShowingSchedule = false

    /// A function, not a value: reading it here would re-derive the tag list on every
    /// update, which for a journal of any size is a scan the toolbar does not need until
    /// its menu is opened.
    private var tags: () -> [String] { { workspace.document.recentTags() } }

    /// One action. Everything open comes forward; the editor is where pruning happens.
    private func roll() {
        guard let rolled = Roll.roll(document: workspace.document, today: NaturalDates.today())
        else { return }
        workspace.replaceJournal(with: rolled.serialized)
    }

    var body: some View {
        NavigationStack {
            editor
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Schedule", systemImage: "calendar") { isShowingSchedule = true }
                            .accessibilityIdentifier("nav.schedule")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Roll", systemImage: "arrow.turn.down.right") { roll() }
                            .disabled(workspace.status != .ready)
                            .accessibilityIdentifier("nav.roll")
                    }
                }
        }
        .sheet(isPresented: $isShowingSchedule) {
            NavigationStack { ScheduleView(workspace: workspace) }
        }
        .sheet(isPresented: Binding(
            get: { !workspace.conflicts.isEmpty },
            // Inert. The conflict list is derived from disk, so it already decides
            // whether this screen belongs on screen; re-deriving it *here* meant a
            // resolution's own dismissal could put the sheet straight back up.
            set: { _ in }
        )) {
            NavigationStack { ConflictView(workspace: workspace) }
        }
    }

    private var editor: some View {
        Group {
            switch workspace.status {
            case .loading:
                ProgressView()
            case .ready:
                JournalTextView(
                    text: { workspace.journalText },
                    document: { workspace.document },
                    onEdit: { workspace.applyEdit(range: $0, replacement: $1) },
                    onResync: { workspace.resyncJournal(from: $0) },
                    revision: workspace.journalRevision,
                    revisionIsUndoable: workspace.journalChangeIsUndoable,
                    tags: tags,
                    onDiagnosticTapped: { offeredFix = OfferedFix(lineIndex: $0, document: workspace.document) }
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
            case .failed(let message):
                ContentUnavailableView(
                    "iCloud unavailable",
                    systemImage: "exclamationmark.icloud",
                    description: Text(message)
                )
            }
        }
        .task { await workspace.load() }
        .overlay(alignment: .top) {
            if let writeError = workspace.writeError {
                Label("Not saving: \(writeError)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .padding(8)
                    .background(.regularMaterial, in: .rect(cornerRadius: 8))
                    .padding(8)
                    .accessibilityIdentifier("banner.writeError")
            }
        }
        .sheet(item: $offeredFix) { offer in
            FixItView(
                offer: offer,
                onAccept: {
                    if let updated = offer.applied() {
                        workspace.replaceJournal(with: updated)
                    }
                    offeredFix = nil
                },
                onDismiss: { offeredFix = nil }
            )
            .presentationDetents([.medium, .large])
        }
    }
}
