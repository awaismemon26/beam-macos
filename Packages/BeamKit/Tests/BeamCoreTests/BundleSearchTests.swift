import Foundation
import Testing
@testable import BeamCore

@Suite struct BundleSearchTests {
    let flagsmith = BundleSummary(id: UUID(), name: "flagsmith", openWindows: 2, files: 0)
    let jobs = BundleSummary(id: UUID(), name: "Job applications", openWindows: 0, files: 3)
    let azure = WindowInfo.fixture(id: 1, appName: "Code", title: "azure-pipelines.yml — flagsmith")
    let gmail = WindowInfo.fixture(id: 2, appName: "Google Chrome", title: "Inbox (12) - Gmail")
    let notes = WindowInfo.fixture(id: 3, appName: "Notes", title: "Shopping")

    @Test func emptyQueryListsBundlesThenWindowsAndSelectsTheFirstWindow() {
        let r = BundleSearch.rank(windows: [gmail, notes], bundles: [flagsmith, jobs], query: "")
        #expect(r.items == [.bundle(flagsmith), .bundle(jobs), .window(gmail), .window(notes)])
        #expect(r.selection == 2)
    }

    @Test func emptyQueryWithNoWindowsSelectsZero() {
        let r = BundleSearch.rank(windows: [], bundles: [flagsmith, jobs], query: "  ")
        #expect(r.items == [.bundle(flagsmith), .bundle(jobs)])
        #expect(r.selection == 0)
    }

    @Test func noBundlesBehavesLikeTheWindowRanker() {
        let windows = [gmail, azure, notes]
        let r = BundleSearch.rank(windows: windows, bundles: [], query: "chrome")
        #expect(r.items == WindowSearchRanker.rank(windows, query: "chrome").map { .window($0) })
        #expect(r.selection == 0)
        #expect(BundleSearch.rank(windows: windows, bundles: [], query: "").items == windows.map { .window($0) })
    }

    @Test func aBundleThatMatchesBetterThanAnyWindowIsSelected() {
        // "flagsmith" is an exact bundle name but only a substring of the window title.
        let r = BundleSearch.rank(windows: [azure, gmail], bundles: [flagsmith, jobs], query: "flagsmith")
        #expect(r.items == [.bundle(flagsmith), .window(azure)])
        #expect(r.selection == 0)
    }

    @Test func aWindowThatMatchesAsWellOrBetterIsSelected() {
        // "azure-pipe" matches only the window title; the bundle doesn't match at all.
        let r = BundleSearch.rank(windows: [gmail, azure], bundles: [flagsmith, jobs], query: "azure-pipe")
        #expect(r.items == [.window(azure)])
        #expect(r.selection == 0)

        // Equal tier (both prefix matches): the window wins the selection, bundles stay above.
        let tie = WindowInfo.fixture(id: 4, appName: "Flag Tool", title: "x")
        let r2 = BundleSearch.rank(windows: [tie], bundles: [flagsmith], query: "flag")
        #expect(r2.items == [.bundle(flagsmith), .window(tie)])
        #expect(r2.selection == 1)
    }

    @Test func bundlesStayAboveWindowsEvenWhenTheWindowMatchesBetter() {
        let chromeLike = BundleSummary(id: UUID(), name: "My notes archive", openWindows: 1, files: 0)
        let r = BundleSearch.rank(windows: [notes], bundles: [chromeLike], query: "notes")
        #expect(r.items == [.bundle(chromeLike), .window(notes)])
        #expect(r.selection == 1)
    }

    @Test func bundlesAreRankedByMatchQuality() {
        let loose = BundleSummary(id: UUID(), name: "The big flagsmith plan", openWindows: 0, files: 0)
        let r = BundleSearch.rank(windows: [], bundles: [loose, flagsmith], query: "flagsmith")
        #expect(r.items == [.bundle(flagsmith), .bundle(loose)])
        #expect(r.selection == 0)
    }

    @Test func nothingMatchingSelectsZero() {
        let r = BundleSearch.rank(windows: [gmail], bundles: [flagsmith], query: "zzzz")
        #expect(r.items.isEmpty)
        #expect(r.selection == 0)
    }
}
