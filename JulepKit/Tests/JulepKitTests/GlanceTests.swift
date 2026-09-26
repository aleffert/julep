import Foundation
import Testing
@testable import JulepKit

private func day(_ month: Int, _ d: Int, _ year: Int = 2026) -> Date {
    JournalCalendar.date(month: month, day: d, year: year)!
}

@Suite("Glance")
struct GlanceTests {
    /// The corpus head is sunday 8/30/2026 with one open item and a `done` section.
    let corpus = Document(Corpus.text)

    @Test func theNewestBlockIsWhatIsGlancedAt() {
        let glance = Glance.of(document: corpus, today: day(8, 30))
        #expect(glance.header?.rendered == "sunday 8/30/2026")
        #expect(glance.isCurrent)
        #expect(glance.items.map(\.item.text) == ["chase down the rebate"])
    }

    /// Only the unlabeled section. `done` already happened and `next` is for the day after.
    @Test func doneAndNextAreNotOpen() {
        let document = Document("""
        monday 9/21/2026
        - open one
        done
        - finished
        next
        - later

        """)
        let glance = Glance.of(document: document, today: day(9, 21))
        #expect(glance.items.map(\.item.text) == ["open one"])
    }

    @Test func aBlockFromAnotherDayIsNotCurrentAndCanRoll() {
        let glance = Glance.of(document: corpus, today: day(9, 2))
        #expect(!glance.isCurrent)
        #expect(glance.canRoll)
        // Still the items it has: the widget shows them and says whose day they are.
        #expect(glance.items.map(\.item.text) == ["chase down the rebate"])
    }

    /// The widget's roll button has to go away once today's block exists, or a second tap
    /// writes a second block for the same day. See `Roll.isNeeded`.
    @Test func todaysBlockCannotBeRolledAgain() {
        #expect(!Glance.of(document: corpus, today: day(8, 30)).canRoll)
        #expect(Roll.isNeeded(document: corpus, today: day(8, 31)))
        #expect(!Roll.isNeeded(document: corpus, today: day(8, 30)))
    }

    @Test func anEmptyJournalHasNoHeaderAndRollsToStartOne() {
        let glance = Glance.of(document: Document(""), today: day(9, 21))
        #expect(glance.header == nil)
        #expect(glance.items.isEmpty)
        #expect(!glance.isCurrent)
        #expect(glance.canRoll)
    }

    /// A block with nothing but a header reads as nothing open, which is different from a
    /// journal the widget could not see at all.
    @Test func aBlockWithNoOpenItemsIsEmptyNotMissing() {
        let document = Document("""
        monday 9/21/2026
        done
        - finished

        """)
        let glance = Glance.of(document: document, today: day(9, 21))
        #expect(glance.header?.rendered == "monday 9/21/2026")
        #expect(glance.items.isEmpty)
    }

    @Test func aTaggedItemKeepsItsTagForTheWidgetToStyle() {
        let document = Document("""
        monday 9/21/2026
        - [carbon dating] send the sample

        """)
        let glance = Glance.of(document: document, today: day(9, 21))
        #expect(glance.items.first?.item.tag?.name == "carbon dating")
        #expect(glance.items.first?.item.text == "[carbon dating] send the sample")
    }
}

@Suite("Rolling twice")
@MainActor
struct RollingTwiceTests {
    private func loadedWorkspace(journal: String) async throws -> Workspace {
        let directory = URL.temporaryDirectory.appending(path: "julep-roll-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try journal.write(to: directory.appending(path: "journal.txt"), atomically: true, encoding: .utf8)

        let workspace = Workspace(saveDebounce: .milliseconds(10))
        await workspace.load(resolving: { Container(documentsURL: directory) })
        return workspace
    }

    /// `Roll.apply` only ever prepends, so a second roll on the same day used to write a second
    /// block with the same header rather than doing nothing. The widget makes this reachable by
    /// a stray tap on the home screen, but the in-app button always could.
    @Test func aSecondRollOnTheSameDayChangesNothing() async throws {
        let workspace = try await loadedWorkspace(journal: """
        sunday 8/30/2026
        - chase down the rebate

        """)
        let today = day(9, 2)

        workspace.roll(today: today)
        let afterFirst = workspace.journalText
        #expect(afterFirst.hasPrefix("wednesday 9/2/2026"))

        workspace.roll(today: today)
        #expect(workspace.journalText == afterFirst, "a second block was written for the same day")

        let headers = workspace.document.blocks.map(\.header.rendered)
        #expect(headers.count == Set(headers).count, "two blocks share a date: \(headers)")
    }

    /// And the day after, it rolls again as normal.
    @Test func theNextDayStillRolls() async throws {
        let workspace = try await loadedWorkspace(journal: """
        sunday 8/30/2026
        - chase down the rebate

        """)
        workspace.roll(today: day(9, 2))
        workspace.roll(today: day(9, 3))
        #expect(workspace.journalText.hasPrefix("thursday 9/3/2026"))
        #expect(workspace.document.blocks.count == 3)
    }
}
