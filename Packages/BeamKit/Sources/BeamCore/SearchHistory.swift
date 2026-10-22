import Foundation

/// Recent searches for one search field, newest first. Recorded only when a result is used.
public struct SearchHistory: Codable, Equatable, Sendable {
    public private(set) var entries: [String]
    private let capacity: Int

    public init(capacity: Int = 100) {
        self.capacity = capacity
        entries = []
    }

    /// Restores saved entries (newest first), trimmed to `capacity`.
    public init(capacity: Int = 100, entries: [String]) {
        self.capacity = capacity
        self.entries = Array(entries.prefix(capacity))
    }

    /// Trims `query`; a repeat (ignoring case) moves to the top with its latest spelling.
    public mutating func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entries.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        entries.insert(trimmed, at: 0)
        if entries.count > capacity { entries.removeLast(entries.count - capacity) }
    }

    public mutating func clear() { entries.removeAll() }
}

/// Walks a `SearchHistory` with ↑ (older) and ↓ (newer). Browsing starts only from an empty field and
/// ends on ↓ past the newest entry or on `reset()` (any edit the user makes).
public struct HistoryNavigator: Sendable {
    /// Index into `entries` of the recalled entry; nil when not browsing.
    private var position: Int?

    public init() {}

    public var isBrowsing: Bool { position != nil }

    /// The next older entry, or nil when there is nothing to recall: not browsing and the field has text,
    /// no history, or already at the oldest.
    public mutating func older(in history: SearchHistory, fieldIsEmpty: Bool) -> String? {
        let entries = history.entries
        guard let current = position else {
            guard fieldIsEmpty, let newest = entries.first else { return nil }
            position = 0
            return newest
        }
        guard current + 1 < entries.count else { return nil }
        position = current + 1
        return entries[current + 1]
    }

    /// The next newer entry; past the newest, "" (the field empties) and browsing ends. Nil when not browsing.
    public mutating func newer(in history: SearchHistory) -> String? {
        guard let current = position else { return nil }
        let entries = history.entries
        guard current > 0, !entries.isEmpty else {
            position = nil
            return ""
        }
        let index = min(current, entries.count) - 1
        position = index
        return entries[index]
    }

    public mutating func reset() { position = nil }
}
