import Foundation

/// Launch history per app, used to rank frequently and recently used apps higher.
public struct UsageStats: Codable, Sendable {
    public static let maxLaunchesPerApp = 20

    /// App id → most recent launch dates, oldest first, at most `maxLaunchesPerApp`.
    public var launches: [String: [Date]] = [:]

    public init() {}

    public mutating func record(_ id: String, at date: Date) {
        var dates = launches[id, default: []]
        dates.append(date)
        if dates.count > Self.maxLaunchesPerApp { dates.removeFirst(dates.count - Self.maxLaunchesPerApp) }
        launches[id] = dates
    }

    /// Sum over launches of `1 / (1 + ageInDays / 7)`: recent launches count most.
    public func frecency(_ id: String, now: Date) -> Double {
        (launches[id] ?? []).reduce(0) { total, date in
            let ageInDays = max(now.timeIntervalSince(date), 0) / 86_400
            return total + 1 / (1 + ageInDays / 7)
        }
    }
}
