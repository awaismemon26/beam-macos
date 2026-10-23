import BeamCore
import SwiftUI

/// What ⌘ G adds to a bundle: a window (as a rule), a file, or a saved file search.
enum PickerTarget: Equatable {
    case window(WindowInfo)
    case file(String)
    case savedSearch(String)

    /// The picker's caption, naming what is being added.
    var caption: String {
        switch self {
        case let .window(window): "Add “\(window.displayTitle)” to a bundle"
        case let .file(path): "Add “\((path as NSString).lastPathComponent)” to a bundle"
        case let .savedSearch(query): "Add the search “\(query)” to a bundle"
        }
    }
}

/// The ⌘ G picker shown in place of a panel's list: existing bundles (filtered by the panel's search field), then
/// "New bundle…", which takes the typed text as its name. Used by window search and the launcher's file results.
struct BundlePicker: View {
    let target: PickerTarget
    let rows: [BundlePickerRow]
    let selection: Int
    let onActivate: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: target.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        rowView(row, isSelected: index == selection)
                            .id(row.id) // must match ForEach's identity
                            .onTapGesture { onActivate(index) }
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.never)
            .onChange(of: selection) { _, index in
                if rows.indices.contains(index) { proxy.scrollTo(rows[index].id) }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: BundlePickerRow, isSelected: Bool) -> some View {
        switch row {
        case let .bundle(bundle):
            BundleRow(bundle: bundle, isSelected: isSelected)
        case let .newBundle(name):
            HStack(spacing: 10) {
                Image(systemName: "plus.square.on.square")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Theme.iconSize - 2, height: Theme.iconSize - 2)
                    .frame(width: Theme.iconSize, height: Theme.iconSize)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                Text(name.isEmpty ? "New bundle…" : "New bundle “\(name)”")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                if name.isEmpty {
                    Text("type a name")
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.secondary))
                }
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
}
