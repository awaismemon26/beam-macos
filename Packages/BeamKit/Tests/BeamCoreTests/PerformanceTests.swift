import Foundation
import Testing
@testable import BeamCore

/// Keystroke budget checks with deliberately large inputs (600 apps, 300 windows): ranking must fit in
/// one 60 Hz frame (16 ms). Release builds measure ~1–2 ms here. Unoptimised (debug) builds run Swift
/// several times slower, so they get three frames. Run `swift test -c release -Xswiftc -enable-testing
/// --filter PerformanceTests` for the shipping numbers.
@Suite struct PerformanceTests {
    #if DEBUG
    static let frameBudget: Duration = .milliseconds(48)
    #else
    static let frameBudget: Duration = .milliseconds(16)
    #endif

    static let words = ["Visual", "Studio", "Code", "Google", "Chrome", "Microsoft", "Teams", "Outlook", "Adobe",
                        "Photoshop", "Final", "Cut", "Pro", "Logic", "Activity", "Monitor", "System", "Settings",
                        "Terminal", "Notes", "Calendar", "Preview", "Safari", "Xcode", "Docker", "Desktop", "Slack"]

    /// 600 installed apps with multi-word names.
    static let apps: [AppEntry] = (0..<600).map { i in
        let name = "\(words[i % words.count]) \(words[(i * 7 + 3) % words.count]) \(i)"
        return AppEntry(id: "/Applications/\(name).app", name: name, bundleID: "dev.test.\(i)")
    }

    /// 300 open windows with long titles.
    static let windows: [WindowInfo] = (0..<300).map { i in
        WindowInfo.fixture(
            id: UInt32(i + 1), pid: Int32(100 + i % 40), appName: words[i % words.count],
            title: "Document \(i) — \(words[(i * 3) % words.count]) project / \(words[(i * 5) % words.count]) notes and more text"
        )
    }

    /// Worst single keystroke while typing `query` letter by letter. Each keystroke is timed three times
    /// and the fastest kept, so scheduler noise from tests running in parallel doesn't count.
    static func worstKeystroke(typing query: String, _ rank: (String) -> Int) -> Duration {
        var worst: Duration = .zero
        for end in query.indices.dropFirst() + [query.endIndex] {
            let prefix = String(query[..<end])
            let clock = ContinuousClock()
            var count = 0
            let best = (0..<3).map { _ in clock.measure { count = rank(prefix) } }.min()!
            #expect(count >= 0)
            worst = max(worst, best)
        }
        return worst
    }

    @Test func appSearchFitsAFrame() {
        var usage = UsageStats()
        for app in Self.apps.prefix(50) { usage.record(app.id, at: Date()) }
        let worst = Self.worstKeystroke(typing: "visual studio code") {
            AppRanker.rank(Self.apps, query: $0, usage: usage, now: Date()).count
        }
        print("app search, 600 apps: worst keystroke \(worst)")
        #expect(worst < Self.frameBudget)
    }

    @Test func windowSearchFitsAFrame() {
        let worst = Self.worstKeystroke(typing: "chrome notes") { WindowSearchRanker.rank(Self.windows, query: $0).count }
        print("window search, 300 windows: worst keystroke \(worst)")
        #expect(worst < Self.frameBudget)
    }

    @Test func mruOrderingFitsAFrame() {
        var mru = MRUList()
        for window in Self.windows.shuffled() { mru.touch(window.id) }
        let clock = ContinuousClock()
        let elapsed = clock.measure { _ = mru.ordered(Self.windows) }
        print("MRU ordering, 300 windows: \(elapsed)")
        #expect(elapsed < Self.frameBudget)
    }

    @Test func calculatorGateIsCheap() {
        let inputs = Self.apps.map(\.name) + ["5 % of 5000", "100 usd in eur", "3pm london in tokyo"]
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for input in inputs { _ = CalculatorGate.looksLikeCalculation(input) }
        }
        print("calculator pre-filter, \(inputs.count) inputs: \(elapsed)")
        #expect(elapsed < Self.frameBudget)
    }
}
