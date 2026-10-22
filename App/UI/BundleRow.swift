import BeamCore
import SwiftUI

/// One bundle in window search and the ⌘ G picker: a stack icon, the name, then "4 windows" in small grey text
/// (the secondary style of the app name in `WindowRow`).
struct BundleRow: View {
    let bundle: BundleSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up")
                .resizable()
                .scaledToFit()
                .frame(width: Theme.iconSize - 2, height: Theme.iconSize - 2)
                .frame(width: Theme.iconSize, height: Theme.iconSize)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            Text(bundle.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            Text(bundle.countText)
                .lineLimit(1)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.secondary))
            Spacer(minLength: 12)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: Theme.rowHeight)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.rowCornerRadius, style: .continuous)
                    .fill(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}
