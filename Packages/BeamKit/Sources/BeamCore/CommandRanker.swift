/// Places Beam's built-in commands relative to app results in root search.
public enum CommandRanker {
    /// The best match of `query` across a command's name and aliases.
    public static func match(_ query: String, names: [String]) -> FuzzyMatch? {
        names.compactMap { FuzzyMatcher.match(query, in: $0) }.max()
    }

    /// A command is listed above the apps only when it matches strictly better (by tier) than the best
    /// app: "settings" → Beam Settings beats System Settings, but "s" keeps Safari on top.
    public static func outranksApps(_ command: FuzzyMatch, bestApp: FuzzyMatch?) -> Bool {
        guard let bestApp else { return true }
        return command.tier > bestApp.tier
    }
}
