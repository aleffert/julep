import Combine
import Sparkle
import SwiftUI

/// Whether asking for an update makes sense right now.
///
/// An `ObservableObject` rather than the `@Observable` the rest of the app uses:
/// `canCheckForUpdates` is a KVO property on someone else's object, and Combine's
/// `publisher(for:)` is what bridges that. The macro only observes properties it owns.
@MainActor
final class UpdaterModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }
}

/// The menu item, as a view rather than a bare `Button`.
///
/// A `CommandGroup` only follows a `disabled` state through a view that observes it, so a
/// button placed in the group directly stays enabled while a check is already running --
/// and a second check started underneath the first is how you get two update dialogs.
struct CheckForUpdatesView: View {
    @ObservedObject private var model: UpdaterModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.model = UpdaterModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…") { updater.checkForUpdates() }
            .disabled(!model.canCheckForUpdates)
            .accessibilityIdentifier("menu.checkForUpdates")
    }
}
