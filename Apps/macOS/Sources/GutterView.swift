import AppKit
import JulepKit

/// One mark in the margin.
///
/// A real view rather than a drawn glyph plus a synthesized accessibility element. AppKit's
/// accessibility frames do not account for a flipped parent, so hand-built elements end up
/// mirrored -- found by identifier, but clicked in the wrong place. A view carries its own
/// frame, hit-testing and accessibility, and none of that has to be reconstructed.
final class GutterMarkView: NSView {
    let line: Int
    let mark: GutterMark
    var onClick: () -> Void = {}

    init(line: Int, mark: GutterMark) {
        self.line = line
        self.mark = mark
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        switch mark {
        case .openItem:
            setAccessibilityIdentifier("gutter.done.\(line)")
            setAccessibilityLabel("Mark done")
        case .diagnostic:
            setAccessibilityIdentifier("gutter.diagnostic.\(line)")
            setAccessibilityLabel("Show problem")
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func mouseDown(with event: NSEvent) { onClick() }

    override func accessibilityPerformPress() -> Bool {
        onClick()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        switch mark {
        case .openItem:
            // A hollow ring: an affordance, not a checkbox. Nothing is checked off
            // without a click.
            let radius: CGFloat = 4.5
            let circle = NSBezierPath(ovalIn: CGRect(
                x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2
            ))
            circle.lineWidth = 1.5
            NSColor.tertiaryLabelColor.setStroke()
            circle.stroke()

        case .diagnostic(let hasFix):
            let name = hasFix ? "exclamationmark.triangle.fill" : "questionmark.circle"
            guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            else { return }
            let size = CGSize(width: 12, height: 12)
            symbol.withSymbolConfiguration(.init(paletteColors: [.systemOrange]))?
                .draw(in: CGRect(
                    x: center.x - size.width / 2, y: center.y - size.height / 2,
                    width: size.width, height: size.height
                ))
        }
    }
}

/// The margin beside the text: a ring to mark an item done, a warning where the app and the
/// file disagree. The macOS counterpart of the iOS gutter, same marks and same meaning.
final class GutterView: NSView {
    var onClickMark: (Int) -> Void = { _ in }

    private var marks: [Int: GutterMark] = [:]
    private var rows: [GutterRow] = []
    /// Row frames by line, so positioning a mark is a lookup rather than a scan. Laying out
    /// runs on every scroll, and searching `rows` for each mark made that quadratic.
    private var rowsByLine: [Int: CGRect] = [:]
    private var markViews: [GutterMarkView] = []

    static let width: CGFloat = 26

    override var isFlipped: Bool { true }

    /// How far the text has scrolled beneath the gutter. Rows arrive in the text view's
    /// coordinates; this is what maps them onto the gutter's own.
    var scrollOffset: CGFloat = 0 {
        didSet {
            guard scrollOffset != oldValue else { return }
            layoutMarkViews()
        }
    }

    func needsUpdate(marks: [Int: GutterMark], rows: [GutterRow]) -> Bool {
        marks != self.marks || rows != self.rows
    }

    func update(marks: [Int: GutterMark], rows: [GutterRow]) {
        self.marks = marks
        self.rows = rows
        rowsByLine = Dictionary(
            rows.map { ($0.line, $0.frame) }, uniquingKeysWith: { first, _ in first }
        )

        markViews.forEach { $0.removeFromSuperview() }
        markViews = rows.compactMap { row in
            guard let mark = marks[row.line] else { return nil }
            let view = GutterMarkView(line: row.line, mark: mark)
            view.onClick = { [weak self] in self?.onClickMark(row.line) }
            addSubview(view)
            return view
        }
        layoutMarkViews()
    }

    override func layout() {
        super.layout()
        layoutMarkViews()
    }

    private func layoutMarkViews() {
        for view in markViews {
            guard let frame = rowsByLine[view.line] else { continue }
            // The fixed width, not `bounds.width`: marks are positioned during `update`,
            // which can run before the width constraint has been applied, and a zero-width
            // mark is present in the hierarchy but impossible to click.
            view.frame = CGRect(
                x: 0, y: frame.minY - scrollOffset,
                width: Self.width, height: max(frame.height, 14)
            )
        }
    }
}

extension NSTextView {
    /// Rows for the marks the gutter can actually draw -- the visible span, not the journal.
    func gutterRows(lineStartOffsets: [Int]) -> [GutterRow] {
        guard let layoutManager = textLayoutManager else { return [] }
        return GutterRows.rows(
            in: layoutManager,
            lineStartOffsets: lineStartOffsets,
            visibleRect: visibleRect,
            topInset: textContainerInset.height,
            width: GutterView.width
        )
    }
}
