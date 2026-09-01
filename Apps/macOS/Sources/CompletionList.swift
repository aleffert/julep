import SwiftUI
import JulepKit

/// The choices, for the popover that drops below the caret.
///
/// Purely a display: it takes no keyboard focus of its own. Focus would go to the list, and
/// then typing an actual date or tag by hand would land in the list rather than in the line.
/// Arrow keys reach it through a key monitor in the coordinator, which lets every other
/// keystroke through to the text view untouched.
struct CompletionList: View {
    let model: CompletionModel
    var onPick: (CompletionOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.options.enumerated()), id: \.element.id) { index, option in
                row(option, isHighlighted: index == model.highlighted)
                    .onTapGesture { onPick(option) }
            }
            Divider().padding(.vertical, 4)
            Text("↑↓ or ⌃N/⌃P to choose · Tab or Return to insert · Esc to dismiss")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
        }
        .padding(6)
        .frame(width: 260, alignment: .leading)
    }

    private func row(_ option: CompletionOption, isHighlighted: Bool) -> some View {
        HStack {
            Text(option.title)
                .font(.body)
            Spacer()
            // What will actually be written, when it differs from the label -- so picking
            // "Tomorrow" never hides which date that meant.
            if let detail = option.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(isHighlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(isHighlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHighlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
        )
        .contentShape(.rect)
        .accessibilityIdentifier("picker.option.\(option.insertion)")
    }
}
