import BeamCore
import SwiftUI

struct WindowSearchView: View {
    @Bindable var model: WindowSearchModel
    let onMove: (Int) -> Void
    let onRecall: (Int) -> Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onActivate: (Int) -> Void
    let onKey: (PanelKey) -> Bool
    /// The bundle view's back arrow.
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SearchField(
                text: $model.query, placeholder: placeholder, focusTrigger: model.presentCount,
                onMove: onMove, onRecall: onRecall, onSubmit: onSubmit, onCancel: onCancel,
                chip: isPicker ? "Add to Bundle" : nil, onKey: onKey
            )
            Divider().opacity(0.4)
            if let bundle = model.openBundle {
                bundleHeader(bundle)
            }
            content
            Divider().opacity(0.4)
            footer
        }
        .frame(width: Theme.rootSize.width, height: Theme.rootSize.height)
        .modifier(ShakeEffect(animatableData: CGFloat(model.shakes)))
    }

    private var isPicker: Bool {
        if case .picker = model.mode { true } else { false }
    }

    private var placeholder: String {
        switch model.mode {
        case .all: "Search windows by app or title…"
        case .bundle: "Search \(model.openBundle?.name ?? "bundle")…"
        case .picker: "Search bundles or name a new one…"
        }
    }

    /// `‹ acme-api`: the bundle's name, and the way back to the main list.
    private func bundleHeader(_ bundle: BeamBundle) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
            Text(bundle.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .contentShape(Rectangle())
        .onTapGesture(perform: onBack)
    }

    @ViewBuilder
    private var content: some View {
        if case let .picker(target) = model.mode {
            BundlePicker(target: target, rows: model.pickerRows, selection: model.selection, onActivate: onActivate)
        } else if model.results.isEmpty {
            VStack {
                Spacer()
                Text(emptyText)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    let headers = sectionHeaders
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, row in
                            VStack(alignment: .leading, spacing: 0) {
                                if let header = headers[index] { SectionHeader(title: header) }
                                rowView(row, isSelected: index == model.selection)
                                    .onTapGesture { onActivate(index) }
                            }
                            .id(row.id) // must match ForEach's identity, or rows show stale items
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

    private var emptyText: String {
        if model.openBundle != nil {
            return model.query.isEmpty ? "No open windows or files in this bundle" : "Nothing in this bundle matches “\(model.query)”"
        }
        return model.query.isEmpty ? "No open windows" : "No windows match “\(model.query)”"
    }

    /// "Bundles" / "Windows" / "Files" above the first row of each kind, only when the list mixes kinds.
    private var sectionHeaders: [Int: String] {
        func title(_ row: WindowSearchRow) -> String {
            switch row {
            case .bundle: "Bundles"
            case .window: "Windows"
            case .file: "Files"
            }
        }
        var headers: [Int: String] = [:]
        var previous: String?
        for (index, row) in model.results.enumerated() where title(row) != previous {
            previous = title(row)
            headers[index] = previous
        }
        return headers.count > 1 ? headers : [:]
    }

    @ViewBuilder
    private func rowView(_ row: WindowSearchRow, isSelected: Bool) -> some View {
        switch row {
        case let .bundle(bundle):
            BundleRow(bundle: bundle, isSelected: isSelected)
        case let .window(window):
            WindowRow(window: window, icon: model.icon(for: window.pid), isSelected: isSelected, showsAppName: true)
        case let .file(item):
            FileRow(file: item.file, icon: model.fileIcons.images[item.file.path], isSelected: isSelected)
                .opacity(item.isMissing ? 0.45 : 1)
        }
    }

    private var footer: some View {
        HStack {
            Text(countText).foregroundStyle(.secondary)
            Spacer()
            Text(hint).foregroundStyle(.tertiary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .frame(height: 30)
    }

    private var countText: String {
        switch model.mode {
        case .all:
            return "\(model.windowCount) windows"
        case .bundle:
            let files = model.fileCount
            return "\(model.windowCount) windows" + (files > 0 ? ", \(files) \(files == 1 ? "file" : "files")" : "")
        case .picker:
            let bundles = model.pickerRows.count { if case .bundle = $0 { true } else { false } }
            return "\(bundles) \(bundles == 1 ? "bundle" : "bundles")"
        }
    }

    private var hint: String {
        switch (model.mode, model.selectedRow) {
        case (.picker, _): "⏎ add   esc back"
        case (.all, .bundle): "⏎ open   ⌘⏎ bring all forward   esc close"
        case (.all, _): "↑↓ select   ⏎ open   ⌘G add to bundle   esc close"
        case (_, .file): "⏎ show in Finder   ⌘⌫ remove   esc back"
        default: "⏎ open   ⌘⏎ bring all forward   ⌘⌫ remove   esc back"
        }
    }
}
