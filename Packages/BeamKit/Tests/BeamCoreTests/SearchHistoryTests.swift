import Foundation
import Testing
@testable import BeamCore

@Suite struct SearchHistoryTests {
    @Test func recordsTrimmedNewestFirst() {
        var h = SearchHistory()
        h.record("  safari ")
        h.record("notes")
        #expect(h.entries == ["notes", "safari"])
    }

    @Test func ignoresEmptyAndWhitespace() {
        var h = SearchHistory()
        h.record("")
        h.record("   \t ")
        #expect(h.entries.isEmpty)
    }

    @Test func duplicateMovesToTopCaseInsensitivelyKeepingLatestSpelling() {
        var h = SearchHistory()
        h.record("Safari")
        h.record("notes")
        h.record("safari")
        #expect(h.entries == ["safari", "notes"])
    }

    @Test func capsAt100DroppingOldest() {
        var h = SearchHistory()
        for i in 1...105 { h.record("q\(i)") }
        #expect(h.entries.count == 100)
        #expect(h.entries.first == "q105")
        #expect(h.entries.last == "q6")
    }

    @Test func clearEmpties() {
        var h = SearchHistory()
        h.record("a")
        h.clear()
        #expect(h.entries.isEmpty)
    }

    @Test func codableRoundTrip() throws {
        var h = SearchHistory(capacity: 5)
        h.record("a"); h.record("b")
        let decoded = try JSONDecoder().decode(SearchHistory.self, from: JSONEncoder().encode(h))
        #expect(decoded == h)
    }
}

@Suite struct HistoryNavigatorTests {
    func history(_ queries: String...) -> SearchHistory {
        var h = SearchHistory()
        for q in queries { h.record(q) } // last argument ends up newest
        return h
    }

    @Test func upOnEmptyFieldRecallsNewest() {
        var n = HistoryNavigator()
        #expect(n.older(in: history("a", "b", "c"), fieldIsEmpty: true) == "c")
        #expect(n.isBrowsing)
    }

    @Test func upAgainGoesOlderAndStopsAtOldest() {
        var n = HistoryNavigator()
        let h = history("a", "b", "c")
        #expect(n.older(in: h, fieldIsEmpty: true) == "c")
        #expect(n.older(in: h, fieldIsEmpty: false) == "b")
        #expect(n.older(in: h, fieldIsEmpty: false) == "a")
        #expect(n.older(in: h, fieldIsEmpty: false) == nil)
        #expect(n.isBrowsing)
        #expect(n.newer(in: h) == "b") // still positioned at the oldest
    }

    @Test func downGoesNewerThenReturnsEmptyAndEndsBrowsing() {
        var n = HistoryNavigator()
        let h = history("a", "b")
        _ = n.older(in: h, fieldIsEmpty: true)
        _ = n.older(in: h, fieldIsEmpty: false)
        #expect(n.newer(in: h) == "b")
        #expect(n.newer(in: h) == "")
        #expect(!n.isBrowsing)
        #expect(n.newer(in: h) == nil)
    }

    @Test func upOnNonEmptyFieldDoesNothingWhenNotBrowsing() {
        var n = HistoryNavigator()
        #expect(n.older(in: history("a"), fieldIsEmpty: false) == nil)
        #expect(!n.isBrowsing)
    }

    @Test func upWithNoHistoryDoesNothing() {
        var n = HistoryNavigator()
        #expect(n.older(in: SearchHistory(), fieldIsEmpty: true) == nil)
        #expect(!n.isBrowsing)
    }

    @Test func resetEndsBrowsing() {
        var n = HistoryNavigator()
        let h = history("a", "b")
        _ = n.older(in: h, fieldIsEmpty: true)
        n.reset()
        #expect(!n.isBrowsing)
        #expect(n.newer(in: h) == nil)
        #expect(n.older(in: h, fieldIsEmpty: true) == "b") // starts again from the newest
    }

    @Test func historyClearedWhileBrowsingIsSafe() {
        var n = HistoryNavigator()
        let h = history("a", "b")
        _ = n.older(in: h, fieldIsEmpty: true)
        #expect(n.older(in: SearchHistory(), fieldIsEmpty: false) == nil)
        #expect(n.newer(in: SearchHistory()) == "")
        #expect(!n.isBrowsing)
    }
}
