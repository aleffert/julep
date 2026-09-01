import Foundation

extension String {
    /// Sentence case, leaving the rest alone -- `.capitalized` would turn `every 2 weeks`
    /// into `Every 2 Weeks`.
    public var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }

    /// The inverse, for when a capitalised phrase ends up mid-sentence.
    public var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}

/// One offer in the `@schedule(` picker.
public struct ScheduleSuggestion: Identifiable, Equatable, Sendable {
    /// What the user reads.
    public var title: String
    /// What gets written between the parentheses.
    public var argument: String

    public var id: String { argument }

    public init(title: String, argument: String) {
        self.title = title
        self.argument = argument
    }
}

/// The choices the picker offers, shared so both platforms agree on them.
public enum ScheduleSuggestions {
    /// One-tap deferrals, resolved to concrete dates because the file must never store
    /// something whose meaning depends on when it is read.
    public static func soon(from today: Date = NaturalDates.today()) -> [ScheduleSuggestion] {
        [("Tomorrow", 1), ("Next week", 7), ("In two weeks", 14), ("In a month", 30)]
            .map { label, days in
                ScheduleSuggestion(
                    title: label,
                    argument: NaturalDates.canonical(NaturalDates.day(days, after: today))
                )
            }
    }

    /// The repeats worth one tap. Anything else can still be typed by hand, and is kept
    /// verbatim rather than resolved.
    ///
    /// Titled for reading, argued for writing: the journal's rules are lowercase, but a menu
    /// row is a sentence about one, not the rule itself.
    public static let repeats: [ScheduleSuggestion] = [
        "every day", "every week", "every 2 weeks", "every month",
    ].map { ScheduleSuggestion(title: $0.capitalizedFirst, argument: $0) }
}
