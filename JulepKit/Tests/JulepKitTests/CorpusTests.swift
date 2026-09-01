import Foundation
import Testing
@testable import JulepKit

/// The corpus is the fixture every grammar and diagnostics test runs against.
/// It is deliberately left dirty -- its defects are what diagnostics is verified on.
enum Corpus {
    static let text: String = {
        let url = Bundle.module.url(forResource: "corpus", withExtension: "txt")!
        return try! String(contentsOf: url, encoding: .utf8)
    }()
}

@Test func corpusResourceLoads() {
    #expect(Corpus.text.contains("sunday 8/30/2026"))
    #expect(Corpus.text.split(separator: "\n", omittingEmptySubsequences: false).count > 500)
}
