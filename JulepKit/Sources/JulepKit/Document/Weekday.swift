import Foundation

/// The seven weekday words a day header can begin with, always lowercase in the journal.
public enum Weekday: String, CaseIterable, Sendable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday

    /// For the app's own prose. `rawValue` is the journal's spelling and stays lowercase,
    /// because that is what gets written to the file; a sentence *about* a Tuesday should
    /// still say Tuesday.
    public var displayName: String { rawValue.capitalized }

    /// `Calendar`'s 1-based weekday numbering, where Sunday is 1.
    public var calendarValue: Int {
        switch self {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
    }

    public init?(calendarValue: Int) {
        switch calendarValue {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
