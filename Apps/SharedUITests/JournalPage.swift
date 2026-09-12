import XCTest

/// What a test can do to the journal, said once, in the app's own vocabulary.
///
/// The two shells reach the same operations by genuinely different routes -- a tag is opened
/// from the menu bar on the Mac and from the keyboard toolbar on the phone, a suggestion is
/// taken with Return there and a tap here. A scenario written against those routes is a
/// scenario written twice, and two copies are how the shells drifted: the caret-after-undo
/// bug existed on both platforms and was found on one, because the test that would have
/// caught it had been written only for the Mac.
///
/// So the *route* lives in a per-platform driver and the *scenario* lives once, above this.
@MainActor
protocol JournalPage: AnyObject {
    /// Seeds the file and launches the app pointed at it, caret at the end of the text.
    func launch(journal: String)

    func type(_ text: String)

    /// Opens a tag on the caret's item, by whatever affordance the platform offers.
    func openTag()

    /// Takes the named suggestion from the open completion list.
    func acceptCompletion(named name: String) 

    /// Whether the completion list is offering `name`, waiting for it to appear.
    func offersCompletion(named name: String, timeout: TimeInterval) -> Bool

    func undo()

    /// The journal as the editor currently shows it.
    var text: String { get }
}

extension JournalPage {
    func offersCompletion(named name: String) -> Bool {
        offersCompletion(named: name, timeout: 5)
    }
}
