import UIKit
import JulepKit

/// One mark in the margin.
///
/// A view per mark rather than one `draw(_:)` across the whole margin. The gutter spans the
/// entire journal so that it scrolls with the text for free, and a view that draws is handed
/// a bitmap the size of its bounds -- which at journal length is an allocation UIKit
/// eventually declines. That failure is silent and total: the marks still hit-test and still
/// speak to VoiceOver, because those are geometry, while nothing is drawn at all. A mark's
/// own view is a few dozen points tall whatever the journal does. The macOS gutter is built
/// the same way, for a different reason.
final class GutterMarkView: UIView {
    let mark: GutterMark

    init(mark: GutterMark) {
        self.mark = mark
        super.init(frame: .zero)
        backgroundColor = .clear
        // Taps belong to the container, which grows each row to a thumb-sized target and
        // knows which line was hit. A mark is decoration.
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ rect: CGRect) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        switch mark {
        case .openItem:
            // A hollow ring: an affordance, not a checkbox. Nothing is checked off
            // without a tap.
            let radius: CGFloat = 7
            let circle = UIBezierPath(
                arcCenter: center, radius: radius,
                startAngle: 0, endAngle: .pi * 2, clockwise: true
            )
            circle.lineWidth = 1.5
            UIColor.tertiaryLabel.setStroke()
            circle.stroke()

        case .diagnostic(let hasFix):
            let symbol = UIImage(
                systemName: hasFix ? "exclamationmark.triangle.fill" : "questionmark.circle"
            )?.withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
            guard let symbol else { return }
            let size = CGSize(width: 18, height: 18)
            symbol.draw(in: CGRect(
                x: center.x - size.width / 2, y: center.y - size.height / 2,
                width: size.width, height: size.height
            ))
        }
    }
}

/// The margin beside the text: a dot to mark an item done, a warning where the app and the
/// file disagree.
///
/// Lives inside the text view's scroll content, so it scrolls with the text for free rather
/// than needing its offset tracked. Line positions come from TextKit 2's layout fragments,
/// because wrapped lines make uniform row heights wrong.
///
/// Draws nothing itself -- see `GutterMarkView` for why that matters at journal length.
final class GutterView: UIView {
    var onTapMark: (Int) -> Void = { _ in }

    private var marks: [Int: GutterMark] = [:]
    private var rows: [GutterRow] = []

    static let width: CGFloat = 38

    /// The smallest comfortable touch target. A mark is only as tall as its line -- around
    /// 20pt -- so the area that responds has to be grown well past what is drawn.
    private static let minimumTouchTarget: CGFloat = 44

    /// The line's frame, grown to something a thumb can actually hit.
    private func touchTarget(for frame: CGRect) -> CGRect {
        let grow = max(0, Self.minimumTouchTarget - frame.height) / 2
        return frame.insetBy(dx: 0, dy: -grow)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Undo

    /// The margin takes first responder when it is tapped, so that shake-to-undo has
    /// somewhere to land.
    ///
    /// Checking an item off is an edit, but it is made without the keyboard up -- and with
    /// nothing focused there is no responder chain, so UIKit looks for an undo manager and
    /// finds none. The shake did nothing at all, while the same undo reached from the
    /// keyboard toolbar worked, because that route asks the text view directly.
    override var canBecomeFirstResponder: Bool { true }

    /// The text view's, which is where the edit registered. A manager of its own would be an
    /// empty one, which is the same problem with more steps.
    override var undoManager: UndoManager? { superview?.undoManager }

    /// Whether anything the gutter draws has actually changed. Guards against a layout loop.
    func needsUpdate(marks: [Int: GutterMark], rows: [GutterRow]) -> Bool {
        marks != self.marks || rows != self.rows
    }

    func update(marks: [Int: GutterMark], rows: [GutterRow]) {
        self.marks = marks
        self.rows = rows
        rebuildAccessibilityElements()
        layoutMarkViews()
    }

    // MARK: - Marks

    /// The view drawing each line's mark, by line.
    ///
    /// Kept and repositioned rather than rebuilt: rows change on every frame of a scroll, and
    /// tearing down a screenful of views that many times a second is work for nothing.
    private var markViews: [Int: GutterMarkView] = [:]

    /// The smallest a mark may be drawn in. A row is only as tall as its line, and a ring of
    /// radius 7 does not fit in one that has been squeezed.
    private static let minimumMarkHeight: CGFloat = 20

    private func layoutMarkViews() {
        var live: Set<Int> = []
        for row in rows {
            guard let mark = marks[row.line] else { continue }
            live.insert(row.line)

            let view: GutterMarkView
            // A line whose mark has changed -- an open item that is now a diagnostic -- needs
            // a new view, because a mark view draws the one it was made with.
            if let existing = markViews[row.line], existing.mark == mark {
                view = existing
            } else {
                markViews[row.line]?.removeFromSuperview()
                view = GutterMarkView(mark: mark)
                addSubview(view)
                markViews[row.line] = view
            }

            let height = max(row.frame.height, Self.minimumMarkHeight)
            view.frame = CGRect(
                x: 0, y: row.frame.midY - height / 2, width: Self.width, height: height
            )
        }

        for (line, view) in markViews where !live.contains(line) {
            view.removeFromSuperview()
            markViews[line] = nil
        }
    }

    // MARK: - Accessibility

    /// The marks are drawn, not laid out, so each one is published as an accessibility
    /// element by hand. Without this the margin is invisible to VoiceOver -- and to any test
    /// that wants to press one.
    private var elements: [UIAccessibilityElement] = []

    override var accessibilityElements: [Any]? {
        get { elements }
        set { _ = newValue }
    }

    private func rebuildAccessibilityElements() {
        elements = rows.compactMap { row in
            guard let mark = marks[row.line] else { return nil }
            let element = UIAccessibilityElement(accessibilityContainer: self)
            element.accessibilityFrameInContainerSpace = touchTarget(for: row.frame)
            element.accessibilityTraits = .button
            switch mark {
            case .openItem:
                element.accessibilityIdentifier = "gutter.done.\(row.line)"
                element.accessibilityLabel = "Mark done"
            case .diagnostic:
                element.accessibilityIdentifier = "gutter.diagnostic.\(row.line)"
                element.accessibilityLabel = "Show problem"
            }
            return element
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        guard let row = rows.first(where: { touchTarget(for: $0.frame).contains(point) }),
              marks[row.line] != nil
        else { return }
        // Only when the editor is not already focused: taking first responder from it would
        // dismiss the keyboard, which is not what tapping a mark in the margin should do.
        if superview?.isFirstResponder != true { becomeFirstResponder() }
        onTapMark(row.line)
    }

}

extension UITextView {
    /// Rows for the marks the gutter can actually draw -- the visible span, not the journal.
    ///
    /// `bounds` rather than a separate visible rect: a scroll view's bounds origin *is* its
    /// content offset, and the gutter lives in that same content space.
    func gutterRows(lineStartOffsets: [Int]) -> [GutterRow] {
        guard let layoutManager = textLayoutManager else { return [] }
        return GutterRows.rows(
            in: layoutManager,
            lineStartOffsets: lineStartOffsets,
            visibleRect: bounds,
            topInset: textContainerInset.top,
            width: GutterView.width
        )
    }
}
