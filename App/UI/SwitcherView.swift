import BeamCore
import SwiftUI

struct SwitcherView: View {
    let model: SwitcherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.4)
            content
                .padding(6)
        }
        .frame(minWidth: Theme.switcherMinWidth, maxWidth: Theme.switcherMaxWidth)
        .fixedSize()
        .modifier(ShakeEffect(animatableData: CGFloat(model.shakes)))
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = model.appIcon {
                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
            }
            Text(model.appName).font(.system(size: 12, weight: .semibold))
            Text(model.windows.count == 1 ? "1 window" : "\(model.windows.count) windows")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if model.windows.isEmpty {
            Text("No open windows")
                .foregroundStyle(.secondary)
                .frame(height: Theme.rowHeight)
                .padding(.horizontal, 10)
        } else if model.windows.count <= Theme.maxVisibleSwitcherRows {
            rows
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) { rows }
                    .frame(height: Theme.rowHeight * CGFloat(Theme.maxVisibleSwitcherRows))
                    .onChange(of: model.highlighted) { _, index in
                        if model.windows.indices.contains(index) {
                            proxy.scrollTo(model.windows[index].id, anchor: .center)
                        }
                    }
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                WindowRow(window: window, icon: nil, isSelected: index == model.highlighted)
                    .id(window.id) // must match ForEach's identity, or rows show stale windows
            }
        }
    }
}
