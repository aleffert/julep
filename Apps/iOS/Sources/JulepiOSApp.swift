import SwiftUI
import UIKit
import WidgetKit
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
    @State private var pendingSave = PendingSave()

    @Environment(\.scenePhase) private var scenePhase

    /// A function, not a value: reading it here would re-derive the tag list on every
    /// update, which for a journal of any size is a scan the toolbar does not need until
    /// its menu is opened.
    private var tags: () -> [String] { { workspace.document.recentTags() } }

    var body: some View {
        NavigationStack {
            editor
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Schedule", systemImage: "calendar") { isShowingSchedule = true }
                            .accessibilityIdentifier("nav.schedule")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Roll", systemImage: "arrow.turn.down.right") {
                            workspace.roll()
                            pendingSave.run(workspace)
                        }
                            .disabled(workspace.status != .ready)
                            .accessibilityIdentifier("nav.roll")
                    }
                }
        }
        .sheet(isPresented: $isShowingSchedule) {
            NavigationStack { ScheduleView(workspace: workspace) }
        }
        // Saving is debounced, and iOS freezes the process on the way out -- so leaving the
        // app within a fraction of a second of a keystroke used to strand that keystroke in
        // memory, where it stays until the app is opened again or reclaimed, whichever comes
        // first. Only one of those puts it in the file.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // The widget rolls the journal from its own process while this one is suspended,
                // and a suspended process's file presenter hears nothing -- so on the way back
                // in, the file is authoritative and has to be re-read.
                Task { await workspace.reload() }
            case .inactive, .background:
                pendingSave.run(workspace)
            @unknown default:
                pendingSave.run(workspace)
            }
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

/// Sees a write through to the file, and tells the widget once it is there.
///
/// A background task assertion, not just a `Task`: once iOS suspends the app, work in flight
/// simply stops until the app is foregrounded again -- which for an app the system later
/// reclaims is never. The assertion is what turns "start writing" into "finish writing".
///
/// The widget reads the journal file rather than a summary the app hands it, so it is told after
/// the write lands, not when it was scheduled. Reloading any earlier just shows the old journal.
@MainActor
@Observable
final class PendingSave {
    private var assertion: UIBackgroundTaskIdentifier = .invalid

    func run(_ workspace: Workspace) {
        // A save already on its way covers this one: the store's write loop re-reads the text
        // each pass, so it picks up anything typed since without a second assertion.
        guard assertion == .invalid else { return }
        assertion = UIApplication.shared.beginBackgroundTask(withName: "Save journal") {
            // Delivered on the main thread just before the time runs out. Ending the
            // assertion here is what keeps the app from being killed for overstaying.
            MainActor.assumeIsolated { self.end() }
        }
        Task {
            await workspace.flush()
            WidgetCenter.shared.reloadAllTimelines()
            end()
        }
    }

    private func end() {
        guard assertion != .invalid else { return }
        UIApplication.shared.endBackgroundTask(assertion)
        assertion = .invalid
    }
}
