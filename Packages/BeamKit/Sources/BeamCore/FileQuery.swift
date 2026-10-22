import Foundation

/// Turns launcher text into a Spotlight file-name query.
public enum FileQuery {
    /// The text after `f ` when it has at least one non-space character; nil for a plain `f` or a word like `figma`.
    /// Lowercase `f` only.
    public static func prefixedTerms(_ launcherQuery: String) -> String? {
        guard launcherQuery.first == "f" else { return nil }
        let rest = launcherQuery.dropFirst()
        guard let separator = rest.first, separator.isWhitespace else { return nil }
        let text = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Whitespace-separated words; word order is irrelevant to matching.
    public static func terms(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// One `kMDItemFSName LIKE[cd] %@` clause per term, joined by `&&`: every word must appear in the file name,
    /// ignoring case and diacritics. Arguments are `*term*` with `*` and `\` escaped; Spotlight's LIKE has no
    /// `?` wildcard, so `?` stays literal (escaping it would make such names unfindable).
    public static func predicateFormat(terms: [String]) -> (format: String, arguments: [String]) {
        let format = terms.map { _ in "kMDItemFSName LIKE[cd] %@" }.joined(separator: " && ")
        let arguments = terms.map { term -> String in
            var escaped = ""
            for character in term {
                if character == "\\" || character == "*" { escaped.append("\\") }
                escaped.append(character)
            }
            return "*\(escaped)*"
        }
        return (format, arguments)
    }

    /// The predicate's test, locally: every term appears in `name`, ignoring case and diacritics. Lets results
    /// for a shorter query stay on screen, filtered, while Spotlight answers the longer one.
    public static func nameMatches(_ name: String, terms: [String]) -> Bool {
        terms.allSatisfy { name.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}

/// Short, readable folder paths for file rows and the File Search settings.
public enum FilePaths {
    private static let iCloudDrive = "Library/Mobile Documents/com~apple~CloudDocs"

    /// `~/Downloads` for a folder in the home folder, `iCloud Drive/…` inside iCloud Drive, else unchanged.
    public static func display(_ folder: String, home: String) -> String {
        if let rest = relative(folder, to: "\(home)/\(iCloudDrive)") { return "iCloud Drive" + rest }
        if let rest = relative(folder, to: home) { return "~" + rest }
        return folder
    }

    /// The folder that contains `path`.
    public static func folder(of path: String) -> String {
        (path as NSString).deletingLastPathComponent
    }

    /// `""` or `"/sub/path"` when `path` is `base` or inside it; nil otherwise (`/Users/xy` is not inside `/Users/x`).
    private static func relative(_ path: String, to base: String) -> String? {
        if path == base { return "" }
        guard path.hasPrefix(base + "/") else { return nil }
        return String(path.dropFirst(base.count))
    }
}

/// One file found by Spotlight.
public struct FileResult: Hashable, Sendable {
    public let path: String
    public let name: String
    public let lastUsed: Date?
    public let modified: Date?

    public init(path: String, name: String, lastUsed: Date?, modified: Date?) {
        self.path = path
        self.name = name
        self.lastUsed = lastUsed
        self.modified = modified
    }
}

public enum FileRanker {
    /// Most recently used first, then most recently modified, then by name; files without a date come last.
    public static func sorted(_ results: [FileResult]) -> [FileResult] {
        results.sorted { a, b in
            if a.lastUsed != b.lastUsed { return isLater(a.lastUsed, b.lastUsed) }
            if a.modified != b.modified { return isLater(a.modified, b.modified) }
            let order = a.name.localizedStandardCompare(b.name)
            return order == .orderedSame ? a.path < b.path : order == .orderedAscending
        }
    }

    private static func isLater(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case let (a?, b?): a > b
        case (_?, nil): true
        default: false
        }
    }
}

public enum FileScopes {
    /// The folders File Search covers until the user changes them.
    public static func defaults(home: String) -> [String] {
        ["Desktop", "Documents", "Downloads", "Pictures", "Library/Mobile Documents/com~apple~CloudDocs"]
            .map { "\(home)/\($0)" }
    }
}
