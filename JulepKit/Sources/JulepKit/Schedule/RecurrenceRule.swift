import Foundation

/// Turns `every 2 weeks` into something that can generate dates.
public enum RecurrenceRuleParser {
    nonisolated(unsafe) private static let pattern =
        #/^every\s+(?:(?<count>\d+)\s+)?(?<unit>[a-z]+)$/#

    public static func rule(from text: String) -> Calendar.RecurrenceRule? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard let match = trimmed.wholeMatch(of: pattern) else { return nil }

        let interval = match.count.flatMap { Int($0) } ?? 1
        guard interval > 0 else { return nil }
        let unit = String(match.unit)

        // `every tuesday` is a weekly rule pinned to that weekday, not an interval.
        if let weekday = Weekday(rawValue: unit) {
            var rule = Calendar.RecurrenceRule(
                calendar: JournalCalendar.calendar, frequency: .weekly, interval: interval
            )
            rule.weekdays = [.every(weekday.localeWeekday)]
            return rule
        }

        let frequency: Calendar.RecurrenceRule.Frequency? = switch unit {
        case "day", "days": .daily
        case "week", "weeks": .weekly
        case "month", "months": .monthly
        case "year", "years": .yearly
        default: nil
        }
        guard let frequency else { return nil }
        return Calendar.RecurrenceRule(
            calendar: JournalCalendar.calendar, frequency: frequency, interval: interval
        )
    }
}

extension Weekday {
    var localeWeekday: Locale.Weekday {
        switch self {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }
}
