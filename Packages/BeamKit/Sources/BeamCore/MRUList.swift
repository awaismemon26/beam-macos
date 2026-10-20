/// Most-recently-used window IDs, newest first.
public struct MRUList: Sendable {
    private var ids: [UInt32] = []
    private let capacity: Int

    public init(capacity: Int = 500) {
        self.capacity = max(capacity, 1)
    }

    public mutating func touch(_ id: UInt32) {
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
        if ids.count > capacity { ids.removeLast(ids.count - capacity) }
    }

    public mutating func remove(_ id: UInt32) {
        ids.removeAll { $0 == id }
    }

    public func contains(_ id: UInt32) -> Bool { ids.contains(id) }

    /// Touched windows first (most recent first); the rest keep their input order.
    public func ordered(_ windows: [WindowInfo]) -> [WindowInfo] {
        let rank = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return windows.enumerated()
            .sorted { a, b in
                switch (rank[a.element.id], rank[b.element.id]) {
                case let (ra?, rb?): return ra < rb
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return a.offset < b.offset
                }
            }
            .map(\.element)
    }
}
