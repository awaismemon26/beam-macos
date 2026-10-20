import SwiftUI

/// One generic row in root search (apps, commands).
struct ResultRow: View {
    let icon: NSImage?
    var systemImage: String?
    let title: String
    let subtitle: String?
    let accessory: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable()
                } else if let systemImage {
                    Image(systemName: systemImage).resizable().scaledToFit().padding(2)
                } else {
                    Color.clear
                }
            }
            .frame(width: Theme.iconSize + 4, height: Theme.iconSize + 4)

            Text(title)
                .lineLimit(1)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            if let subtitle {
                Text(subtitle)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 12)
            if let accessory {
                Text(accessory)
                    .font(.caption)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            }
        }
        .font(.system(size: 14))
        .padding(.horizontal, 10)
        .frame(height: Theme.rowHeight + 4)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.rowCornerRadius, style: .continuous)
                    .fill(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}
