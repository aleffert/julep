import Foundation
import Testing
@testable import JulepKit

@Suite("Version diff")
struct VersionDiffTests {
    private func hunks(_ comparison: VersionDiff.Comparison) -> [VersionDiff.Hunk] {
        guard case .hunks(let hunks) = comparison else { return [] }
        return hunks
    }

    private func rows(_ comparison: VersionDiff.Comparison) -> [VersionDiff.Row] {
        hunks(comparison).flatMap(\.rows)
    }

    @Test func identicalTextHasNothingToChooseBetween() {
        #expect(VersionDiff.compare(mine: Corpus.text, theirs: Corpus.text) == .identical)
    }

    /// The shape a real conflict takes: a roll landed on one device and not the other, so one
    /// side has a block at the head and the rest of the file matches.
    @Test func aBlockAddedAtTheHeadIsTheOnlyThingShown() {
        let mine = "monday 8/31/2026\n- older\n- history"
        let theirs = "tuesday 9/1/2026\n- typed on the phone\n\nmonday 8/31/2026\n- older\n- history"

        let comparison = VersionDiff.compare(mine: mine, theirs: theirs)
        let rows = rows(comparison)

        #expect(rows.filter { $0.side == .theirs }.map(\.text)
            == ["tuesday 9/1/2026", "- typed on the phone", ""])
        #expect(rows.allSatisfy { $0.side != .mine })
        // The unchanged history is context, and there is little enough of it to keep all.
        #expect(rows.filter { $0.side == .shared }.map(\.text) == ["monday 8/31/2026", "- older", "- history"])
    }

    @Test func aLineChangedOnEachSideShowsBothLines() {
        let mine = "a\nb\nmine\nd\ne"
        let theirs = "a\nb\ntheirs\nd\ne"

        let rows = rows(VersionDiff.compare(mine: mine, theirs: theirs))

        #expect(rows.filter { $0.side == .mine }.map(\.text) == ["mine"])
        #expect(rows.filter { $0.side == .theirs }.map(\.text) == ["theirs"])
        // Removals before insertions, the order a diff is read in.
        let differing = rows.filter { $0.side != .shared }
        #expect(differing.map(\.side) == [.mine, .theirs])
    }

    /// The reason the diff exists: months of matching history must not be printed.
    @Test func distantHistoryIsCollapsedAway() {
        let history = (1...200).map { "- day \($0)" }.joined(separator: "\n")
        let mine = "header\n" + history
        let theirs = "header\n- inserted\n" + history

        let comparison = VersionDiff.compare(mine: mine, theirs: theirs, context: 3)
        let rows = rows(comparison)

        #expect(hunks(comparison).count == 1)
        // One changed line plus context either side -- not two hundred lines of agreement.
        #expect(rows.count <= 8)
        #expect(rows.contains { $0.side == .theirs && $0.text == "- inserted" })
    }

    /// Two separate edits stay two hunks, so the gap between them can be announced.
    @Test func separateEditsAreSeparateHunks() {
        let filler = (1...40).map { "line \($0)" }
        var theirLines = filler
        theirLines[0] = "changed at the top"
        theirLines[39] = "changed at the bottom"

        let comparison = VersionDiff.compare(
            mine: filler.joined(separator: "\n"),
            theirs: theirLines.joined(separator: "\n")
        )
        let hunks = hunks(comparison)

        #expect(hunks.count == 2)
        #expect(hunks[0].end < hunks[1].start)
        // Everything between the two is dropped, which is what the gap marker counts.
        #expect(hunks[1].start - hunks[0].end - 1 > 0)
    }

    @Test func lineNumbersPointIntoThisDevicesVersion() {
        let mine = "a\nb\nc\nd"
        let theirs = "a\nb\nX\nc\nd"

        let rows = rows(VersionDiff.compare(mine: mine, theirs: theirs))

        #expect(rows.first(where: { $0.text == "a" })?.line == 1)
        // The inserted line borrows the number of the line it lands before.
        #expect(rows.first(where: { $0.side == .theirs })?.line == 3)
        #expect(rows.first(where: { $0.text == "c" })?.line == 3)
    }

    /// A wholesale rewrite is reported rather than rendered: a page of alternating lines
    /// tells the user nothing they can act on.
    @Test func aWholesaleRewriteIsReportedAsCountsInstead() {
        let mine = (1...300).map { "mine \($0)" }.joined(separator: "\n")
        let theirs = (1...300).map { "theirs \($0)" }.joined(separator: "\n")

        guard case .tooDifferent(let mineOnly, let theirsOnly) =
            VersionDiff.compare(mine: mine, theirs: theirs, limit: 200)
        else {
            Issue.record("expected the two to be reported as too different")
            return
        }
        #expect(mineOnly == 300)
        #expect(theirsOnly == 300)
    }

    @Test func emptinessOnEitherSideIsHandled() {
        #expect(VersionDiff.compare(mine: "", theirs: "") == .identical)

        let added = rows(VersionDiff.compare(mine: "", theirs: "a\nb"))
        #expect(added.filter { $0.side == .theirs }.map(\.text) == ["a", "b"])

        let removed = rows(VersionDiff.compare(mine: "a\nb", theirs: ""))
        #expect(removed.filter { $0.side == .mine }.map(\.text) == ["a", "b"])
    }
}
