import Foundation
import Testing
@testable import BeamCore

@Suite struct AppRankerTests {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let day: TimeInterval = 86_400

    func app(_ name: String) -> AppEntry { AppEntry(id: "/Applications/\(name).app", name: name, bundleID: nil) }

    @Test func recordCapsAt20() {
        var u = UsageStats()
        for i in 0..<25 { u.record("a", at: now.addingTimeInterval(Double(i))) }
        #expect(u.launches["a"]?.count == 20)
        #expect(u.launches["a"]?.last == now.addingTimeInterval(24))
    }
    @Test func recentBeatsOld() {
        var u = UsageStats()
        u.record("recent", at: now)
        for _ in 0..<3 { u.record("old", at: now.addingTimeInterval(-90 * day)) }
        #expect(u.frecency("recent", now: now) > u.frecency("old", now: now))
    }
    @Test func usageBreaksTiesWithinTier() {
        var u = UsageStats()
        u.record(app("Notion").id, at: now.addingTimeInterval(-day))
        let r = AppRanker.rank([app("Notes"), app("Notion")], query: "no", usage: u, now: now)
        #expect(r.map(\.name) == ["Notion", "Notes"])
    }
    @Test func betterTierBeatsUsage() {
        var u = UsageStats()
        for _ in 0..<20 { u.record(app("Microsoft Teams").id, at: now) }
        let r = AppRanker.rank([app("Microsoft Teams"), app("Terminal")], query: "term", usage: u, now: now)
        #expect(r.first?.name == "Terminal")
    }
    @Test func emptyQueryShowsMostUsed() {
        var u = UsageStats()
        u.record(app("Safari").id, at: now)
        u.record(app("Mail").id, at: now); u.record(app("Mail").id, at: now)
        let r = AppRanker.rank([app("Notes"), app("Safari"), app("Mail")], query: "", usage: u, now: now)
        #expect(r.map(\.name) == ["Mail", "Safari", "Notes"])
    }
    @Test func limitRespected() {
        let apps = (0..<20).map { app("App \($0)") }
        #expect(AppRanker.rank(apps, query: "app", usage: UsageStats(), now: now, limit: 8).count == 8)
    }
    @Test func usageStatsRoundTrip() throws {
        var u = UsageStats(); u.record("x", at: now)
        let decoded = try JSONDecoder().decode(UsageStats.self, from: JSONEncoder().encode(u))
        #expect(decoded.launches == u.launches)
    }
}
