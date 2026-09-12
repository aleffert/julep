import XCTest

/// Every scenario in `SharedEditorScenarios`, run against the phone.
final class IOSSharedScenarios: SharedEditorScenarios {
    override func makePage() -> JournalPage { IOSJournalPage() }
}
