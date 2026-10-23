import BeamCore
import SwiftUI

struct RootSearchView: View {
    @Bindable var model: RootSearchModel
    let onQueryChange: () -> Void
    let onMove: (Int) -> Void
    let onRecall: (Int) -> Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onActivate: (Int) -> Void
    let onSettings: () -> Void
    let onKey: (PanelKey) -> Bool

    private var isFileView: Bool { model.mode == .files }

    private var placeholder: String {
        switch model.mode {
        case .root: "Search apps or calculate…"
        case .files: "Search files…"
        case .picker: "Search bundles or name a new one…"
        }
    }

    private var chip: String? {
        switch model.mode {
        case .root: nil
        case .files: "Search Files"
        case .picker: "Add to Bundle"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(
                text: $model.query, placeholder: placeholder,
                focusTrigger: model.presentCount,
                onMove: onMove, onRecall: onRecall, onSubmit: onSubmit, onCancel: onCancel, onCommandComma: onSettings,
                chip: chip, onKey: onKey
            )
            .onChange(of: model.query) { onQueryChange() }
            Divider().opacity(0.4)
            if case let .picker(target) = model.mode {
                BundlePicker(target: target, rows: model.pickerRows, selection: model.selection, onActivate: onActivate)
            } else {
                list
            }
            Divider().opacity(0.4)
            footer
        }
        .frame(width: Theme.rootSize.width, height: Theme.rootSize.height)
        .modifier(ShakeEffect(animatableData: CGFloat(model.shakes)))
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if case .file = model.items.first {
                        sectionHeader("Files")
                    } else if model.query.isEmpty && !model.items.isEmpty {
                        sectionHeader("Suggestions")
                    }
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        row(item, isSelected: index == model.selection)
                            .id(item.id) // must match ForEach's identity, or rows show stale items
                            .onTapGesture { onActivate(index) }
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.never)
            .onChange(of: model.selection) { _, index in
                if model.items.indices.contains(index) { proxy.scrollTo(model.items[index].id) }
            }
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
        case let .file(file):
            FileRow(file: file, icon: model.fileIcons.images[file.path], isSelected: isSelected)
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
        if model.isPicker { return "⏎ add   esc back" }
        guard model.items.indices.contains(model.selection) else { return "esc close" }
        switch model.items[model.selection] {
        case .calculation: return "⏎ copy answer   esc close"
        case .app: return "⏎ open   esc close"
        case .command: return "⏎ run   esc close"
        case .file: return "⏎ show in Finder   ⌘⏎ open   ⌘G add to bundle   ⇧⌘G save search   esc close"
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
