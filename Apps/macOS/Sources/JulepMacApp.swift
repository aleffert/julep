import SwiftUI
import Sparkle
import JulepKit

@main
struct JulepMacApp: App {
    /// Started at launch rather than built when the menu is opened: Sparkle's own
    /// scheduler is what checks in the background, and an updater that only exists while
    /// a menu is down would never run one.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    init() { ContainerDiagnostic.runIfRequested() }

    var body: some Scene {
        Window("Julep", id: "journal") {
            JournalView()
                .frame(minWidth: 520, minHeight: 400)
        }
        .commands {
            // Directly under About Julep, where a Mac looks for it.
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandMenu("Item") {
                // What clicking the gutter does, for the item the caret is on -- the same
                // operation, reached the way a Mac expects to reach it.
                // Sent to nil so it reaches whatever is first responder -- the text view.
                Button("Toggle Done") {
                    NSApp.sendAction(#selector(JournalNSTextView.toggleDone(_:)), to: nil, from: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }
}

struct JournalView: View {
    @State private var workspace = Workspace()
    @State private var offeredFix: OfferedFix?
    @State private var isShowingSchedule = false

    /// One action. Everything open comes forward; the editor is where pruning happens.
    private func roll() {
        guard let rolled = Roll.roll(document: workspace.document, today: NaturalDates.today())
        else { return }
        workspace.replaceJournal(with: rolled.serialized)
    }

    var body: some View {
        editor
            .toolbar {
                ToolbarItem {
                    Button("Schedule", systemImage: "calendar") { isShowingSchedule = true }
                        .accessibilityIdentifier("nav.schedule")
                }
                ToolbarItem {
                    Button("Roll", systemImage: "arrow.turn.down.right") { roll() }
                        .disabled(workspace.status != .ready)
                        .accessibilityIdentifier("nav.roll")
                }
            }
            .sheet(isPresented: $isShowingSchedule) {
                NavigationStack { ScheduleView(workspace: workspace) }
                    .frame(minWidth: 420, minHeight: 480)
            }
            .sheet(isPresented: Binding(
                get: { !workspace.conflicts.isEmpty },
                set: { if !$0 { workspace.checkForConflicts() } }
            )) {
                NavigationStack { ConflictView(workspace: workspace) }
                    .frame(minWidth: 460, minHeight: 480)
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
                    onDiagnosticClicked: { offeredFix = OfferedFix(lineIndex: $0, document: workspace.document) }
                )
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
        }
    }
}
