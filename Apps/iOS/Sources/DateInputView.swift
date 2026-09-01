import UIKit
import JulepKit

/// The calendar that takes the keyboard's place while a date is being picked.
///
/// The *input* view rather than a sheet, which is the whole point: a sheet takes first
/// responder, so by the time it returns a date the editor has lost the caret it was meant to
/// write at -- and finding the annotation again by searching the text lands on whichever one
/// sits lowest in the file, which with blocks newest-first is an older one further down.
/// Swapping the input view leaves the text view first responder throughout, so the caret is
/// still exactly where the user left it.
///
/// Taller than the keyboard it replaces, so the editor shifts further up than it does for
/// typing. That is the price of a month grid, and a month grid is what a date that is not
/// "tomorrow" is picked from -- the near dates, which the wheels are faster for, are already
/// one tap away on the suggestion strip.
final class DateInputView: UIInputView {
    let picker = UIDatePicker()

    /// Enough for the grid plus its month header. The inline picker sizes itself, but an
    /// input view is asked for a height before it lays out, so one is given.
    private static let height: CGFloat = 360

    init() {
        super.init(
            frame: CGRect(x: 0, y: 0, width: 0, height: Self.height), inputViewStyle: .keyboard
        )
        // Explicitly opaque. An input view sits in `UITextEffectsWindow`, whose backdrop is
        // empty, so a material here has nothing to sample and the journal shows straight
        // through the calendar -- see the note in `CompletionStrip`. Matched to the keyboard
        // this stands in for.
        backgroundColor = .systemGray5

        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.accessibilityIdentifier = "picker.date.calendar"

        addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            picker.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            picker.topAnchor.constraint(equalTo: topAnchor),
            picker.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// The date under the selection, as the journal would write it.
    ///
    /// Through `today(now:)` first: the picker hands back a moment, and the file stores days.
    var argument: String { NaturalDates.canonical(NaturalDates.today(now: picker.date)) }
}

/// Cancel and confirm, in the accessory slot above the calendar.
///
/// The confirm button names the date it would write rather than saying "Done", so what a tap
/// is about to put in the journal is legible before it lands -- the same reason a suggestion
/// capsule carries the date under "Tomorrow".
final class DateInputBar: UIToolbar {
    var onCancel: () -> Void = {}
    var onAccept: () -> Void = {}

    private lazy var accept = UIBarButtonItem(
        title: "", primaryAction: UIAction { [weak self] _ in self?.onAccept() }
    )

    init() {
        super.init(frame: .zero)
        sizeToFit()
        let cancel = UIBarButtonItem(
            title: "Cancel", primaryAction: UIAction { [weak self] _ in self?.onCancel() }
        )
        cancel.accessibilityIdentifier = "picker.date.cancel"
        accept.accessibilityIdentifier = "picker.date.use"
        accept.style = .prominent
        items = [cancel, UIBarButtonItem(systemItem: .flexibleSpace), accept]
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(_ argument: String) {
        accept.title = "Use \(argument)"
    }
}
