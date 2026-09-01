import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// One laid-out line, and the frame its first line fragment occupies.
///
/// The *first* fragment line rather than the whole fragment: a wrapped item makes the
/// fragment several rows tall, and line spacing pads it further, so a mark derived from the
/// fragment box alone sits above the text rather than beside it.
public struct GutterRow: Equatable, Sendable {
    public var line: Int
    public var frame: CGRect

    public init(line: Int, frame: CGRect) {
        self.line = line
        self.frame = frame
    }
}

/// Where the gutter's marks go, for the part of the journal that is actually on screen.
///
/// Shared by both shells because the computation is identical; only the inset and the margin
/// width differ, and those are passed in.
public enum GutterRows {
    /// How far beyond the visible rect to compute, as a fraction of its height, so a scroll
    /// reveals marks that are already positioned instead of a blank margin waiting for the
    /// next refresh.
    private static let overscan: CGFloat = 0.5

    /// What to cover when the view has no geometry yet.
    ///
    /// A text view is asked for rows before it has been laid out, and an empty visible rect
    /// would mean no marks at all until something else happened to trigger a refresh. A
    /// nominal first screenful keeps a freshly opened journal from looking unmarked, and the
    /// first real geometry replaces it. Deliberately not the whole document: falling back to
    /// that would lay out years of history at launch, which is what this exists to avoid.
    private static let assumedHeight: CGFloat = 1200

    /// Rows for the lines within (or just outside) `visibleRect`.
    ///
    /// Deliberately *not* the whole document. Enumerating every fragment with `.ensuresLayout`
    /// forces TextKit 2 to lay out the entire journal, which in turn drives the paragraph
    /// delegate over every line -- so the highlighter's per-viewport cost quietly becomes
    /// per-document, on every keystroke. Years of history make that unusable.
    ///
    /// `visibleRect` and the returned frames are in the text view's coordinates; fragment
    /// frames are in the container's, which `topInset` bridges.
    public static func rows(
        in layoutManager: NSTextLayoutManager,
        lineStartOffsets: [Int],
        visibleRect: CGRect,
        topInset: CGFloat,
        width: CGFloat
    ) -> [GutterRow] {
        guard let contentManager = layoutManager.textContentManager else { return [] }
        let documentStart = contentManager.documentRange.location

        let known = visibleRect.height > 0
            ? visibleRect
            : CGRect(x: 0, y: 0, width: visibleRect.width, height: assumedHeight)
        let wanted = known.insetBy(dx: 0, dy: -known.height * overscan)
        let top = wanted.minY - topInset
        let bottom = wanted.maxY - topInset
        guard bottom >= 0 else { return [] }

        // Start at the fragment covering the top of the wanted rect rather than at the
        // document, so scrolled-past history is never walked.
        let start = layoutManager.textLayoutFragment(for: CGPoint(x: 0, y: max(top, 0)))?
            .rangeInElement.location
            ?? layoutManager.documentRange.location

        var rows: [GutterRow] = []
        layoutManager.enumerateTextLayoutFragments(
            from: start,
            options: [.ensuresLayout, .ensuresExtraLineFragment]
        ) { fragment in
            let frame = fragment.layoutFragmentFrame
            guard frame.minY <= bottom else { return false }

            let offset = contentManager.offset(
                from: documentStart, to: fragment.rangeInElement.location
            )
            guard let line = lineIndex(for: offset, in: lineStartOffsets) else { return true }

            let firstLine = fragment.textLineFragments.first?.typographicBounds
                ?? CGRect(origin: .zero, size: frame.size)
            rows.append(GutterRow(line: line, frame: CGRect(
                x: 0,
                y: frame.minY + firstLine.minY + topInset,
                width: width,
                height: firstLine.height
            )))
            return true
        }
        return rows
    }

    /// The lines these rows cover, as a range -- what to ask the document about.
    public static func lineSpan(of rows: [GutterRow]) -> Range<Int> {
        guard let first = rows.first?.line, let last = rows.last?.line else { return 0..<0 }
        return min(first, last)..<(max(first, last) + 1)
    }

    private static func lineIndex(for offset: Int, in starts: [Int]) -> Int? {
        guard !starts.isEmpty, offset >= 0 else { return nil }
        var low = 0
        var high = starts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if starts[middle] <= offset { low = middle } else { high = middle - 1 }
        }
        return low
    }
}
