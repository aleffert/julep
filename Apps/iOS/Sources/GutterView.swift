import UIKit
import JulepKit

/// The margin beside the text: a dot to mark an item done, a warning where the app and the
/// file disagree.
///
/// Lives inside the text view's scroll content, so it scrolls with the text for free rather
/// than needing its offset tracked. Line positions come from TextKit 2's layout fragments,
/// because wrapped lines make uniform row heights wrong.
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
        setNeedsDisplay()
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

    override func draw(_ rect: CGRect) {
        for row in rows {
            guard let mark = marks[row.line], row.frame.intersects(rect) else { continue }
            let center = CGPoint(x: bounds.midX, y: row.frame.minY + row.frame.height / 2)

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
                guard let symbol else { continue }
                let size = CGSize(width: 18, height: 18)
                symbol.draw(in: CGRect(
                    x: center.x - size.width / 2, y: center.y - size.height / 2,
                    width: size.width, height: size.height
                ))
            }
        }
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
