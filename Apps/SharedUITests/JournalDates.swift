import Foundation

/// A deferral date far enough ahead that it is not yet due, in the journal's own format.
///
/// Computed rather than written into a fixture. A literal date is only in the future until
/// the calendar reaches it, and what a deferral *means* changes the moment it does: a roll
/// injects it into the new block, and the schedule list stops showing its date and says "due
/// now" instead. A test pinned to a literal then starts failing on a day nobody chose, for a
/// reason that has nothing to do with the code it covers -- which is how `9/8/2026` in
/// `testAnnotatedItemsAreNotCarried` came to fail two weeks after it was written.
@MainActor
func dateNotYetDue(inDays days: Int = 30) -> String {
    let day = Calendar.current.date(byAdding: .day, value: days, to: Date())!
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "M/d/yyyy"
    return formatter.string(from: day)
}
