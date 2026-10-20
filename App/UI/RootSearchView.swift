import BeamCore
import SwiftUI

struct RootSearchView: View {
    @Bindable var model: RootSearchModel
    let onQueryChange: () -> Void
    let onMove: (Int) -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onActivate: (Int) -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SearchField(
                text: $model.query, placeholder: "Search apps or calculate…", focusTrigger: model.presentCount,
                onMove: onMove, onSubmit: onSubmit, onCancel: onCancel, onCommandComma: onSettings
            )
            .onChange(of: model.query) { onQueryChange() }
            Divider().opacity(0.4)
            list
            Divider().opacity(0.4)
            footer
        }
        .frame(width: Theme.rootSize.width, height: Theme.rootSize.height)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if model.query.isEmpty && !model.items.isEmpty {
                        sectionHeader("Suggestions")
                    }
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        row(item, isSelected: index == model.selection)
                            .id(index)
                            .onTapGesture { onActivate(index) }
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.never)
            .onChange(of: model.selection) { _, index in proxy.scrollTo(index) }
        }
    }

    @ViewBuilder
    private func row(_ item: RootItem, isSelected: Bool) -> some View {
        switch item {
        case let .calculation(result):
            CalculatorCard(result: result, isSelected: isSelected, showsCopied: model.showsCopied)
        case let .app(app):
            ResultRow(icon: model.icons[app.id], title: app.name, subtitle: nil, accessory: "Application",
                      isSelected: isSelected)
        case let .command(command):
            ResultRow(icon: nil, systemImage: command.systemImage, title: command.rawValue, subtitle: nil,
                      accessory: "Command", isSelected: isSelected)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 6)
    }

    private var footer: some View {
        HStack {
            Image(systemName: "command.square").foregroundStyle(.secondary)
            Text("Beam").foregroundStyle(.secondary)
            Spacer()
            Text(footerHint).foregroundStyle(.tertiary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .frame(height: 30)
    }

    private var footerHint: String {
        guard model.items.indices.contains(model.selection) else { return "esc close" }
        switch model.items[model.selection] {
        case .calculation: return "⏎ copy answer   esc close"
        case .app: return "⏎ open   esc close"
        case .command: return "⏎ run   esc close"
        }
    }
}

/// Raycast-style calculator result: expression → large answer.
struct CalculatorCard: View {
    let result: CalculationResult
    let isSelected: Bool
    let showsCopied: Bool

    var body: some View {
        HStack(spacing: 16) {
            Text(result.expression)
                .font(.system(size: 22, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)
            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                Text(result.value)
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .textSelection(.enabled)
                Text(showsCopied ? "Copied" : "Enter to copy")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .padding(.bottom, 6)
        .contentShape(Rectangle())
    }
}
