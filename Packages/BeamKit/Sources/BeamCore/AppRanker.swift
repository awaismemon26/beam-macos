import Foundation

public enum AppRanker {
    /// Empty query: most used first. Otherwise: match tier, then frecency, then match score, then shorter name.
    public static func rank(_ apps: [AppEntry], query: String, usage: UsageStats, now: Date, limit: Int = 8) -> [AppEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return apps
                .map { (app: $0, frecency: usage.frecency($0.id, now: now)) }
                .sorted { $0.frecency != $1.frecency ? $0.frecency > $1.frecency : $0.app.name < $1.app.name }
                .prefix(limit)
                .map(\.app)
        }
        let prepared = PreparedQuery(q)
        return apps
            .compactMap { app in
                FuzzyMatcher.match(prepared, in: app.name).map { (app: app, match: $0, frecency: usage.frecency(app.id, now: now)) }
            }
            .sorted { a, b in
                if a.match.tier != b.match.tier { return a.match.tier > b.match.tier }
                if a.frecency != b.frecency { return a.frecency > b.frecency }
                if a.match.score != b.match.score { return a.match.score > b.match.score }
                return a.app.name.count < b.app.name.count
            }
            .prefix(limit)
            .map(\.app)
    }
}
