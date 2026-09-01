import SwiftUI
import JulepKit

/// A diagnostic the user asked about, resolved against the text at that moment.
struct OfferedFix: Identifiable {
    let lineIndex: Int
    let diagnostic: Diagnostic
    /// The journal as it stood when the mark was clicked. Held so the fix is applied to the
    /// text it was computed from, even if typing has moved on behind the sheet.
    let document: Document
    var id: Int { lineIndex }

    init?(lineIndex: Int, document: Document) {
        // Only this line was asked about, so only this line is analyzed. The neighbouring
        // blocks its date is checked against are still consulted -- see `analyze(_:lines:)`.
        guard let diagnostic = Diagnostics
            .analyze(document, lines: lineIndex..<(lineIndex + 1)).first
        else { return nil }
        self.lineIndex = lineIndex
        self.diagnostic = diagnostic
        self.document = document
    }

    /// The lines the fix would replace, and what it would put there.
    var change: (before: [String], after: [String])? {
        guard let fix = diagnostic.fix else { return nil }
        guard fix.range.upperBound <= document.lines.count else { return nil }
        return (document.lines[fix.range].map(\.raw), fix.replacement)
    }

    func applied() -> String? {
        guard let fix = diagnostic.fix else { return nil }
        return document.applying(fix).serialized
    }
}

/// Shows a proposed correction, with the reasoning and the exact change.
///
/// The whole point of this app over Notes is that it proposes and explains rather than
/// silently correcting, so the change itself is the thing worth showing -- an alert could
/// only ever paraphrase it.
struct FixItView: View {
    let offer: OfferedFix
    var onAccept: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Text(offer.diagnostic.reasoning)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let change = offer.change {
                VStack(alignment: .leading, spacing: 8) {
                    lines("Now", change.before, tint: .secondary, strikethrough: true)
                    lines("After", change.after, tint: .primary, strikethrough: false)
                }
            }

            HStack {
                Spacer()
                Button("Leave it", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                if let fix = offer.diagnostic.fix {
                    Button(fix.summary, action: onAccept)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 380, idealWidth: 460)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: offer.diagnostic.fix == nil
                  ? "questionmark.circle.fill"
                  : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(offer.diagnostic.title)
                .font(.headline)
            Spacer()
        }
    }

    /// The affected lines, boxed so the exact text is unmistakable -- these are the bytes in
    /// the file, not a description of them.
    private func lines(
        _ caption: String, _ content: [String], tint: HierarchicalShapeStyle, strikethrough: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(content.enumerated()), id: \.offset) { _, line in
                    Text(line.isEmpty ? " " : line)
                        .strikethrough(strikethrough, color: .secondary)
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
        }
    }
}
