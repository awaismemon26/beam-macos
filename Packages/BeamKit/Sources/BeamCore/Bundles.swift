import Foundation

/// A named group for one project or task: window rules, files and saved file searches.
public struct BeamBundle: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var rules: [BundleRule]
    /// Absolute paths, kept as-is (missing files are shown greyed by the UI).
    public var files: [String]
    /// File-search queries that live-list matching files within the File Search scopes.
    public var savedSearches: [String]

    public init(id: UUID = UUID(), name: String, rules: [BundleRule] = [], files: [String] = [], savedSearches: [String] = []) {
        self.id = id
        self.name = name
        self.rules = rules
        self.files = files
        self.savedSearches = savedSearches
    }
}

/// Which windows belong to a bundle. Windows are transient (new IDs after a restart), so a rule names an app
/// and a title key instead of a window.
public struct BundleRule: Codable, Equatable, Sendable {
    public enum Match: String, Codable, Sendable {
        /// The window's extracted `TitleKey` equals `key` (rules created with ⌘ G).
        case exact
        /// The window's title contains `key` (rules written by hand in Settings).
        case contains
    }

    /// `nil` = any app.
    public var appBundleID: String?
    public var key: String
    public var match: Match
    /// Set for windows without a stable title key (browsers): matches that one window, this session only.
    /// Never persisted — `BundleStore` drops such rules on load.
    public var sessionWindowID: UInt32?

    public init(appBundleID: String?, key: String, match: Match, sessionWindowID: UInt32? = nil) {
        self.appBundleID = appBundleID
        self.key = key
        self.match = match
        self.sessionWindowID = sessionWindowID
    }
}

public enum BundleMatcher {
    /// An empty key matches nothing, so a half-edited rule never swallows every window.
    public static func matches(_ rule: BundleRule, _ window: WindowInfo) -> Bool {
        if let sessionWindowID = rule.sessionWindowID { return window.id == sessionWindowID }
        if let app = rule.appBundleID, app != window.bundleID { return false }
        guard !rule.key.isEmpty else { return false }
        switch rule.match {
        case .exact:
            guard let key = TitleKey.extract(appBundleID: window.bundleID, title: window.title) else { return false }
            return equalsIgnoringCase(key, rule.key)
        case .contains:
            return containsIgnoringCase(window.title, rule.key)
        }
    }

    /// Case-insensitive substring test. Matching runs for every rule × window on each panel open, and Foundation's
    /// `range(of:options:)` is several times slower than a byte scan, so ASCII keys (nearly all of them) skip it.
    private static func containsIgnoringCase(_ haystack: String, _ needle: String) -> Bool {
        var haystack = haystack, needle = needle
        let found: Bool? = haystack.withUTF8 { h in
            needle.withUTF8 { n in
                guard !n.contains(where: { $0 >= 0x80 }) else { return nil }
                guard n.count <= h.count else { return false }
                var start = 0
                while start + n.count <= h.count {
                    var i = 0
                    while i < n.count, lower(h[start + i]) == lower(n[i]) { i += 1 }
                    if i == n.count { return true }
                    start += 1
                }
                return false
            }
        }
        return found ?? (haystack.range(of: needle, options: .caseInsensitive) != nil)
    }

    private static func equalsIgnoringCase(_ a: String, _ b: String) -> Bool {
        var a = a, b = b
        let equal: Bool? = a.withUTF8 { x in
            b.withUTF8 { y in
                guard !x.contains(where: { $0 >= 0x80 }), !y.contains(where: { $0 >= 0x80 }) else { return nil }
                guard x.count == y.count else { return false }
                var i = 0
                while i < x.count, lower(x[i]) == lower(y[i]) { i += 1 }
                return i == x.count
            }
        }
        return equal ?? (a.lowercased() == b.lowercased())
    }

    private static func lower(_ byte: UInt8) -> UInt8 { (65...90).contains(byte) ? byte + 32 : byte }

    /// The bundle's open windows, in the order given (callers pass most recently used first).
    public static func windows(of bundle: BeamBundle, in windows: [WindowInfo]) -> [WindowInfo] {
        windows.filter { window in bundle.rules.contains { matches($0, window) } }
    }

    /// The rules ⌘ ⌫ removes for a window: those that name that window — its this-session rule, or an exact
    /// title-key rule for its app and key. Broad rules ("title contains", any app) also cover other windows, so they
    /// are left for the Settings rule editor; a window in the bundle only through them has nothing to remove.
    public static func removableRules(for window: WindowInfo, in bundle: BeamBundle) -> [BundleRule] {
        let key = TitleKey.extract(appBundleID: window.bundleID, title: window.title)
        return bundle.rules.filter { rule in
            if let sessionWindowID = rule.sessionWindowID { return sessionWindowID == window.id }
            guard rule.match == .exact, let app = rule.appBundleID, app == window.bundleID, let key else { return false }
            return equalsIgnoringCase(rule.key, key)
        }
    }

    /// The rule ⌘ G adds for a window: an exact title-key rule, or a this-session rule when there is no stable key.
    public static func rule(for window: WindowInfo) -> BundleRule {
        if let key = TitleKey.extract(appBundleID: window.bundleID, title: window.title) {
            return BundleRule(appBundleID: window.bundleID, key: key, match: .exact)
        }
        return BundleRule(appBundleID: window.bundleID, key: window.title, match: .exact, sessionWindowID: window.id)
    }
}

/// The `bundles.json` format: `{"version":1,"bundles":[…]}`.
public struct BundleFile: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version = BundleFile.currentVersion
    public var bundles: [BeamBundle]

    public init(bundles: [BeamBundle]) {
        self.bundles = bundles
    }

    /// `nil` when the data isn't a readable file of a version this build understands (corrupt, hand-broken,
    /// or written by a newer Beam) — the caller must keep it rather than overwrite it.
    public static func decode(_ data: Data) -> BundleFile? {
        guard let file = try? JSONDecoder().decode(BundleFile.self, from: data), file.version <= currentVersion else { return nil }
        return file
    }

    /// Window IDs don't outlive the session, so rules matching one window are never stored or loaded.
    public func withoutSessionRules() -> BundleFile {
        var copy = self
        for index in copy.bundles.indices { copy.bundles[index].rules.removeAll { $0.sessionWindowID != nil } }
        return copy
    }
}
