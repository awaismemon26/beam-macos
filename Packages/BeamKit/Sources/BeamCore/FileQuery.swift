import Foundation

/// Turns launcher text into a Spotlight file-name query.
public enum FileQuery {
    /// The text after `f ` when it has at least one non-space character; nil for a plain `f` or a word like `figma`.
    public static func prefixedTerms(_ launcherQuery: String) -> String? {
        guard let first = launcherQuery.first, first == "f" || first == "F" else { return nil }
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
    /// ignoring case and diacritics. Arguments are `*term*` with LIKE wildcards (`*`, `?`) and `\` escaped.
    public static func predicateFormat(terms: [String]) -> (format: String, arguments: [String]) {
        let format = terms.map { _ in "kMDItemFSName LIKE[cd] %@" }.joined(separator: " && ")
        let arguments = terms.map { term -> String in
            var escaped = ""
            for character in term {
                if character == "\\" || character == "*" || character == "?" { escaped.append("\\") }
                escaped.append(character)
            }
            return "*\(escaped)*"
        }
        return (format, arguments)
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
