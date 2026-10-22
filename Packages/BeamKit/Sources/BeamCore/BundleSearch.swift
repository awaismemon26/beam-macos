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
}
