/// Ranks windows for the Option+Tab search: app-name matches first, then title matches.
public enum WindowSearchRanker {
    /// Common nicknames → the app name they mean.
    public static let aliases: [String: String] = [
        "vscode": "visual studio code", "code": "visual studio code", "teams": "microsoft teams",
        "msteams": "microsoft teams", "chrome": "google chrome", "term": "terminal", "iterm": "iterm2",
    ]

    /// Empty query returns `windows` unchanged (callers pass MRU order). Ties keep input order.
    public static func rank(_ windows: [WindowInfo], query: String) -> [WindowInfo] {
        let q = FuzzyMatcher.normalize(query)
        guard !q.isEmpty else { return windows }
        let queries = [q] + (aliases[q].map { [$0] } ?? [])

        var appHits: [(offset: Int, match: FuzzyMatch, window: WindowInfo)] = []
        var titleHits: [(offset: Int, match: FuzzyMatch, window: WindowInfo)] = []

        for (offset, window) in windows.enumerated() {
            let appMatch = queries
                .flatMap { query in window.appSearchNames.compactMap { FuzzyMatcher.match(query, in: $0) } }
                .max()
            if let appMatch {
                appHits.append((offset, appMatch, window))
            } else if let titleMatch = FuzzyMatcher.match(q, in: window.title), titleMatch.tier >= .substring {
                // Loose subsequence matches across long titles are noise; require at least a substring.
                titleHits.append((offset, titleMatch, window))
            }
        }

        func byMatchThenOrder(_ a: (offset: Int, match: FuzzyMatch, window: WindowInfo),
                              _ b: (offset: Int, match: FuzzyMatch, window: WindowInfo)) -> Bool {
            a.match != b.match ? a.match > b.match : a.offset < b.offset
        }
        return appHits.sorted(by: byMatchThenOrder).map(\.window) + titleHits.sorted(by: byMatchThenOrder).map(\.window)
    }
}
