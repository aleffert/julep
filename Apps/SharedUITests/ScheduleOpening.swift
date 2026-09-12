import Foundation

/// What opens a schedule annotation, spelled once.
///
/// The UI test bundles cannot import JulepKit, so this cannot be `ScheduleAnnotation.opening`
/// itself -- but it can at least be a single literal rather than one per driver.
enum ScheduleOpening {
    static let text = "@schedule("
}
