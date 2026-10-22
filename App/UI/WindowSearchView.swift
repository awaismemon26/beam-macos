import BeamCore
import SwiftUI

struct WindowSearchView: View {
    @Bindable var model: WindowSearchModel
    let onMove: (Int) -> Void
    let onRecall: (Int) -> Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onActivate: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SearchField(
                text: $model.query, placeholder: "Search windows by app or title…", focusTrigger: model.presentCount,
                onMove: onMove, onRecall: onRecall, onSubmit: onSubmit, onCancel: onCancel
            )
            Divider().opacity(0.4)
            results
            Divider().opacity(0.4)
            footer
        }
        .frame(width: Theme.rootSize.width, height: Theme.rootSize.height)
        .modifier(ShakeEffect(animatableData: CGFloat(model.shakes)))
    }

    @ViewBuilder
    private var results: some View {
        if model.results.isEmpty {
            VStack {
                Spacer()
                Text(model.query.isEmpty ? "No open windows" : "No windows match “\(model.query)”")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, window in
                            WindowRow(window: window, icon: model.icon(for: window.pid),
                                      isSelected: index == model.selection, showsAppName: true)
                                .id(window.id) // must match ForEach's identity, or rows show stale windows
                                .onTapGesture { onActivate(index) }
                        }
                    }
                    .padding(6)
                }
                .scrollIndicators(.never)
                .onChange(of: model.selection) { _, index in
                    if model.results.indices.contains(index) { proxy.scrollTo(model.results[index].id) }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(model.results.count) windows").foregroundStyle(.secondary)
            Spacer()
            Text("↑↓ select   ⏎ open   esc close").foregroundStyle(.tertiary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .frame(height: 30)
    }
}
