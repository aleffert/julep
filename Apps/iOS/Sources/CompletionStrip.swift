import UIKit
import JulepKit

/// The row of suggestions that takes over the accessory area while a completion is open.
///
/// Above the keyboard rather than in a popup, because the filtering happens by typing into
/// the journal: anything that took focus would swallow the keystrokes that are meant to
/// narrow the list. This is the shape the system's own suggestion bars use, for the same
/// reason.
///
/// Scrolls horizontally rather than truncating. Typing is what reaches the candidates past
/// the handful offered unprompted, so a list that could not grow past a screenful would make
/// typing pointless.
///
/// ## On the background
///
/// The bar is glass and the capsules on it are glass, merged by a container effect. Be aware
/// of what that costs here, because it is not what glass does elsewhere: an accessory view
/// lives in `UITextEffectsWindow`, a separate window above the app's, so a `UIVisualEffectView`
/// samples *that* window's backdrop -- which is empty -- rather than the journal below it.
/// The material therefore does not obscure the text behind it the way system chrome does.
///
/// That was measured rather than assumed: glass, `UIInputView(.keyboard)` and a plain view
/// were each built and photographed against a full page. Only an explicit opaque colour hides
/// what is behind, and `Self.opaqueBackground` switches to one.
///
/// The failure mode hides itself, which is the part worth remembering: transparency over a
/// blank page looks perfect, so a sparse test journal reports success. Judge it against dense
/// text or not at all.
final class CompletionStrip: UIInputView {
    var onPick: (CompletionOption) -> Void = { _ in }
    /// Tapped on the trailing capsule, where one is offered. See `update(_:offeringDate:)`.
    var onPickDate: () -> Void = {}

    /// Swap to `true` for a flat opaque bar that genuinely obscures the journal behind it.
    /// See the note above on why glass cannot.
    private static let opaqueBackground = false

    /// Matched to the keyboard's, so the two corners line up rather than nearly line up.
    /// Measured off a screenshot: about eleven points of inset at the first row over a
    /// twenty-point run, which is a continuous curve rather than a circular one.
    private static let keyboardCornerRadius: CGFloat = 20

    /// Tall enough that the capsules carry the bar rather than float on it. The more of the
    /// width they cover, the less of the journal shows between them.
    private static let height: CGFloat = 60

    /// A *container* effect rather than a plain glass one: the capsules inside are glass too,
    /// and this is what merges them into a single material instead of stacking panes.
    private let glass = UIVisualEffectView(effect: UIGlassContainerEffect())
    private let scroller = UIScrollView()
    private let row = UIStackView()

    init() {
        super.init(
            frame: CGRect(x: 0, y: 0, width: 0, height: Self.height), inputViewStyle: .keyboard
        )
        // Rounded at the top and square at the bottom, so it continues into the keyboard
        // instead of sitting on it. The system's own suggestion row is *inside* the
        // keyboard's container, which is why those corners belong to it -- an accessory view
        // cannot go there, so it has to finish the shape itself.
        glass.layer.cornerRadius = Self.keyboardCornerRadius
        glass.layer.cornerCurve = .continuous
        glass.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        glass.layer.masksToBounds = true
        if Self.opaqueBackground {
            glass.contentView.backgroundColor = .systemGray5
        }

        addSubview(glass)
        glass.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        scroller.showsHorizontalScrollIndicator = false
        scroller.alwaysBounceHorizontal = true
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center

        glass.contentView.addSubview(scroller)
        scroller.addSubview(row)
        scroller.translatesAutoresizingMaskIntoConstraints = false
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroller.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor),
            scroller.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor),
            scroller.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
            scroller.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: scroller.contentLayoutGuide.leadingAnchor,
                                         constant: 12),
            row.trailingAnchor.constraint(equalTo: scroller.contentLayoutGuide.trailingAnchor,
                                          constant: -12),
            row.centerYAnchor.constraint(equalTo: scroller.frameLayoutGuide.centerYAnchor),
            row.heightAnchor.constraint(equalTo: scroller.frameLayoutGuide.heightAnchor,
                                        multiplier: 0.82),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private var shown: [CompletionOption] = []
    private var showsDate = false

    /// The options, and whether to finish the row with a way to reach a calendar.
    ///
    /// Offered for a date and not for a tag: the four deferrals are the dates worth one tap,
    /// and every other date is a day on a grid. A tag has no such elsewhere -- typing one
    /// nothing matches is how a new tag is made.
    ///
    /// It also means the schedule row is never empty. Typing an argument no suggestion
    /// matches leaves a tag row blank, which is the honest answer there; here there is always
    /// still the calendar.
    func update(_ options: [CompletionOption], offeringDate: Bool = false) {
        guard options != shown || offeringDate != showsDate else { return }
        shown = options
        showsDate = offeringDate
        row.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if offeringDate { row.addArrangedSubview(dateButton()) }
        for option in options { row.addArrangedSubview(button(for: option)) }
        scroller.setContentOffset(.zero, animated: false)
    }

    /// First, where it needs no scrolling to reach. The suggestions are four deferrals and
    /// four repeats, which is more than fits the width -- so a calendar at the far end would
    /// be the one thing on the row you had to go looking for, and the one thing you reach for
    /// precisely when none of the visible answers fit.
    private func dateButton() -> UIButton {
        var configuration = self.configuration()
        configuration.title = "Pick a date"
        configuration.image = UIImage(systemName: "calendar")
        configuration.imagePadding = 6

        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            self?.onPickDate()
        })
        button.accessibilityIdentifier = "picker.date"
        return button
    }

    private func button(for option: CompletionOption) -> UIButton {
        var configuration = self.configuration()
        configuration.title = option.title
        // What will actually be written, when it differs from the label -- so picking
        // "Tomorrow" never hides which date that meant.
        configuration.subtitle = option.detail

        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            self?.onPick(option)
        })
        button.accessibilityIdentifier = "picker.option.\(option.insertion)"
        return button
    }

    /// What every capsule on the bar looks like, whatever it does.
    ///
    /// Glass capsules over a glass bar; a flat fill over a flat one. The two have to move
    /// together: a glass capsule on an opaque background has nothing to sample and
    /// disappears, leaving labels floating with no capsule around them.
    private func configuration() -> UIButton.Configuration {
        var configuration: UIButton.Configuration
        if Self.opaqueBackground {
            configuration = .filled()
            configuration.baseBackgroundColor = .secondarySystemBackground
            configuration.baseForegroundColor = .label
        } else {
            configuration = .glass()
        }
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 8, leading: 18, bottom: 8, trailing: 18
        )
        return configuration
    }
}
