import Foundation
import Testing
@testable import JulepKit

@Suite("Diagnostics")
struct DiagnosticsTests {
    let document = Document(Corpus.text)

    /// Header line (1-based, as the file is numbered) -> what the fix should write.
    /// Derived from the corpus by hand; every one is corroborated by a weekday, a delta, or both.
    static let expectedDateFixes: [(line: Int, was: String, becomes: String, suspect: Diagnostic.DateField)] = [
        (110, "tuesday 6/15/2026",   "tuesday 6/16/2026",   .numericDate),
        (133, "tuesday 6/8/2026",    "tuesday 6/9/2026",    .numericDate),
        (219, "wednesday 3/26/2026", "thursday 3/26/2026",  .weekday),
        (264, "monday 2/28/2026",    "monday 3/2/2026",     .numericDate),
        (488, "tuesday 1/27/2025",   "tuesday 1/27/2026",   .numericDate),
        (518, "wednesday 1/21/2025", "wednesday 1/21/2026", .numericDate),
        (532, "tuesday 1/20/2025",   "tuesday 1/20/2026",   .numericDate),
        (555, "friday 1/16/2025",    "friday 1/16/2026",    .numericDate),
    ]

    @Test func findsTheKnownDefectsAndNothingElse() {
        let found = Diagnostics.analyze(document)
        #expect(found.count == Self.expectedDateFixes.count + 1)  // + the section-order block

        let dates = found.filter { if case .dateDisagreement = $0.kind { return true }; return false }
        #expect(dates.map { $0.lineIndex + 1 } == Self.expectedDateFixes.map(\.line))
    }

    /// The corpus is clean apart from the defects above -- no line defeats the grammar.
    @Test func reportsNoUnrecognizedLines() {
        let found = Diagnostics.analyze(document)
        #expect(!found.contains { $0.kind == .unrecognizedLine })
    }

    @Test("Each date defect is caught, blamed correctly, and corrected",
          arguments: DiagnosticsTests.expectedDateFixes)
    func dateDefect(_ expected: (line: Int, was: String, becomes: String, suspect: Diagnostic.DateField)) {
        let index = expected.line - 1
        #expect(document.lines[index].raw == expected.was, "corpus drifted from the fixture")

        guard let diagnostic = Diagnostics.analyze(document).first(where: { $0.lineIndex == index })
        else { Issue.record("nothing reported at line \(expected.line)"); return }

        #expect(diagnostic.kind == .dateDisagreement(suspect: expected.suspect))
        #expect(diagnostic.fix?.replacement == [expected.becomes])
    }

    /// The one case where the numeric date is *not* the suspect: the delta corroborates the
    /// date, leaving the weekday as the lone dissenter.
    @Test func aCorroboratedDateBlamesTheWeekdayInstead() {
        let index = 219 - 1
        guard let diagnostic = Diagnostics.analyze(document).first(where: { $0.lineIndex == index })
        else { Issue.record("nothing reported"); return }

        #expect(diagnostic.kind == .dateDisagreement(suspect: .weekday))
        #expect(diagnostic.reasoning.contains("delta agrees"))
    }

    /// A delta contradicting two self-consistent headers is the delta's fault, and is
    /// reported on its own.
    @Test func aLoneBadDeltaIsCaught() {
        let document = Document("""
        sunday 6/21/2026
        - a thing

        delta 99 days

        monday 6/15/2026
        - another thing
        """)
        let found = Diagnostics.analyze(document)
        #expect(found.map(\.kind) == [.deltaDisagreement])
        #expect(found[0].fix?.replacement == ["delta 6 days"])
        #expect(document.applying(found.compactMap(\.fix)).serialized.contains("delta 6 days"))
    }

    /// But a gap that is wrong *because* a neighbouring header is wrong is one mistake, not
    /// two. The corpus's `delta 2 days` above `saturday 2/28` is itself correct -- it only
    /// looks wrong because `monday 2/28` above it carries the bad date.
    @Test func aDeltaIsNotBlamedForANeighboursBadDate() {
        let found = Diagnostics.analyze(document)
        #expect(!found.contains { $0.kind == .deltaDisagreement })

        let line = Corpus.text.components(separatedBy: "\n").firstIndex(of: "delta 2 days")
        #expect(line != nil)
        #expect(!found.contains { $0.lineIndex == line })
    }

    @Test func flagsTheOutOfOrderBlockAndOffersAReorder() {
        let index = 72 - 1
        guard let diagnostic = Diagnostics.analyze(document).first(where: { $0.kind == .sectionOrder })
        else { Issue.record("no section-order diagnostic"); return }

        #expect(diagnostic.lineIndex == index)
        #expect(diagnostic.fix?.replacement.first == "done")
        #expect(diagnostic.fix?.replacement.contains("next") == true)
    }
}

@Suite("Applying fixes")
struct FixApplicationTests {
    /// The whole point: accept every offered correction and the journal comes out clean.
    @Test func applyingEveryFixLeavesNoDiagnostics() {
        let document = Document(Corpus.text)
        let fixes = Diagnostics.analyze(document).compactMap(\.fix)
        #expect(fixes.count == 9)

        let repaired = document.applying(fixes)
        #expect(Diagnostics.analyze(repaired).isEmpty)
    }

    /// And it touches only the defective lines -- a linter, not a reformatter.
    @Test func fixesTouchOnlyTheLinesTheyName() {
        let document = Document(Corpus.text)
        let fixes = Diagnostics.analyze(document).compactMap(\.fix)
        let repaired = document.applying(fixes)

        let before = Corpus.text.components(separatedBy: "\n")
        let after = repaired.serialized.components(separatedBy: "\n")
        #expect(before.count == after.count)

        let changed = zip(before, after).enumerated().filter { $0.element.0 != $0.element.1 }
        // Eight headers, plus the seven reordered lines of the 7/22 block.
        #expect(changed.count == 8 + 7)
    }

    @Test func nothingIsAppliedUntilItIsAccepted() {
        let document = Document(Corpus.text)
        _ = Diagnostics.analyze(document)
        #expect(document.serialized == Corpus.text)
    }
}
