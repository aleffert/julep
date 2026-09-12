import XCTest

/// Every scenario in `SharedEditorScenarios`, run against the Mac.
final class MacSharedScenarios: SharedEditorScenarios {
    override func makePage() -> JournalPage { MacJournalPage() }
}
