import BeamCore
import SwiftUI

/// One window in the switcher / window search list.
struct WindowRow: View {
    let window: WindowInfo
    let icon: NSImage?
    let isSelected: Bool
    var showsAppName = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: Theme.iconSize, height: Theme.iconSize)
            }
            Text(window.displayTitle)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            if showsAppName {
                Text(window.appName)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 12)
            if !window.isReachable {
                Text("Can't reach this window")
                    .font(.caption)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            } else if let badge = window.badge {
                Text(badge)
                    .font(.caption)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))
            }
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
        .opacity(window.isReachable ? 1 : 0.45)
        .contentShape(Rectangle())
    }
}
