import Foundation

/// What the window-search list needs to know about a bundle: its row text, not its rules.
public struct BundleSummary: Hashable, Sendable {
    public let id: UUID
    public let name: String
    /// Currently open member windows.
    public let openWindows: Int
    public let files: Int

    public init(id: UUID, name: String, openWindows: Int, files: Int) {
        self.id = id
        self.name = name
        self.openWindows = openWindows
        self.files = files
    }

    /// The summary of `bundle`, counting its members among `windows`.
    public init(_ bundle: BeamBundle, windows: [WindowInfo]) {
        self.init(id: bundle.id, name: bundle.name, openWindows: BundleMatcher.windows(of: bundle, in: windows).count,
                  files: bundle.files.count)
    }

    /// The grey text after the name: "4 windows", "1 window" or "no open windows", plus ", 2 files" when it has any.
    public var countText: String {
        let windows = switch openWindows {
        case 0: "no open windows"
        case 1: "1 window"
        default: "\(openWindows) windows"
        }
        guard files > 0 else { return windows }
        return windows + (files == 1 ? ", 1 file" : ", \(files) files")
    }
}

/// A row of the ⌘ G bundle picker: an existing bundle, or a new one named by what was typed.
public enum BundlePickerRow: Identifiable, Hashable, Sendable {
    case bundle(BundleSummary)
    case newBundle(name: String)

    public var id: String {
        switch self {
        case .bundle(let bundle): "bundle-\(bundle.id.uuidString)"
        case .newBundle: "new-bundle"
        }
    }
}

public enum WindowSearchItem: Identifiable, Hashable, Sendable {
    case bundle(BundleSummary)
    case window(WindowInfo)

    public var id: String {
        switch self {
        case .bundle(let bundle): "bundle-\(bundle.id.uuidString)"
        case .window(let window): "window-\(window.id)"
        }
    }
}

/// The Option+Tab list with bundles: a Bundles section above the usual windows.
public enum BundleSearch {
    /// Empty query: all bundles, then all windows (as given), selecting the first window so ⌥ Tab → Enter still
    /// switches windows. Typing: matching bundles stay above matching windows; the top bundle is selected only
    /// when it matches strictly better (by tier) than every window, otherwise the first window is.
    public static func rank(windows: [WindowInfo], bundles: [BundleSummary], query: String) -> (items: [WindowSearchItem], selection: Int) {
        let q = FuzzyMatcher.normalize(query)
        guard !q.isEmpty else {
            let items = bundles.map(WindowSearchItem.bundle) + windows.map(WindowSearchItem.window)
            return (items, windows.isEmpty ? 0 : bundles.count)
        }

        let prepared = PreparedQuery(q)
        let bundleHits = bundles.enumerated()
            .compactMap { offset, bundle in FuzzyMatcher.match(prepared, in: bundle.name).map { (offset: offset, match: $0, bundle: bundle) } }
            .sorted { $0.match != $1.match ? $0.match > $1.match : $0.offset < $1.offset }
        let windowHits = WindowSearchRanker.rankedMatches(windows, query: q)

        let items = bundleHits.map { WindowSearchItem.bundle($0.bundle) } + windowHits.map { WindowSearchItem.window($0.window) }
        guard let topBundle = bundleHits.first else { return (items, 0) }
        guard let bestWindowTier = windowHits.map(\.match.tier).max(), topBundle.match.tier <= bestWindowTier else { return (items, 0) }
        return (items, bundleHits.count)
    }

    /// The ⌘ G picker: bundles whose names match `query` (best first, all of them for an empty query), then a
    /// "New bundle" row named by the trimmed query — left out when a bundle already has exactly that name.
    /// Typing a name + ⏎ should create that bundle, so the top bundle is selected only when it matches at least by
    /// word prefix ("job" → "Job applications"); a looser match ("api") selects "New bundle". Empty query: row 0.
    public static func pickerRows(bundles: [BundleSummary], query: String) -> (rows: [BundlePickerRow], selection: Int) {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let q = FuzzyMatcher.normalize(query)
        guard !q.isEmpty else { return (bundles.map(BundlePickerRow.bundle) + [.newBundle(name: "")], 0) }

        let prepared = PreparedQuery(q)
        let hits = bundles.enumerated()
            .compactMap { offset, bundle in FuzzyMatcher.match(prepared, in: bundle.name).map { (offset, $0, bundle) } }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
        let rows = hits.map { BundlePickerRow.bundle($0.2) }
        let exists = bundles.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        guard !exists else { return (rows, 0) }
        let topIsClose = hits.first.map { $0.1.tier >= .wordPrefix } ?? false
        return (rows + [.newBundle(name: name)], topIsClose ? 0 : rows.count)
    }
}
