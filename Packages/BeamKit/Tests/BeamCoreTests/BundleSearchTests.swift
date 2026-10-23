import Foundation
import Testing
@testable import BeamCore

@Suite struct BundleSearchTests {
    let acme = BundleSummary(id: UUID(), name: "acme-api", openWindows: 2, files: 0)
    let jobs = BundleSummary(id: UUID(), name: "Job applications", openWindows: 0, files: 3)
    let deploy = WindowInfo.fixture(id: 1, appName: "Code", title: "deploy.yml — acme-api")
    let gmail = WindowInfo.fixture(id: 2, appName: "Google Chrome", title: "Inbox (12) - Gmail")
    let notes = WindowInfo.fixture(id: 3, appName: "Notes", title: "Shopping")

    @Test func emptyQueryListsBundlesThenWindowsAndSelectsTheFirstWindow() {
        let r = BundleSearch.rank(windows: [gmail, notes], bundles: [acme, jobs], query: "")
        #expect(r.items == [.bundle(acme), .bundle(jobs), .window(gmail), .window(notes)])
        #expect(r.selection == 2)
    }

    @Test func emptyQueryWithNoWindowsSelectsZero() {
        let r = BundleSearch.rank(windows: [], bundles: [acme, jobs], query: "  ")
        #expect(r.items == [.bundle(acme), .bundle(jobs)])
        #expect(r.selection == 0)
    }

    @Test func noBundlesBehavesLikeTheWindowRanker() {
        let windows = [gmail, deploy, notes]
        let r = BundleSearch.rank(windows: windows, bundles: [], query: "chrome")
        #expect(r.items == WindowSearchRanker.rank(windows, query: "chrome").map { .window($0) })
        #expect(r.selection == 0)
        #expect(BundleSearch.rank(windows: windows, bundles: [], query: "").items == windows.map { .window($0) })
    }

    @Test func aBundleThatMatchesBetterThanAnyWindowIsSelected() {
        // "acme-api" is an exact bundle name but only a substring of the window title.
        let r = BundleSearch.rank(windows: [deploy, gmail], bundles: [acme, jobs], query: "acme-api")
        #expect(r.items == [.bundle(acme), .window(deploy)])
        #expect(r.selection == 0)
    }

    @Test func aWindowThatMatchesAsWellOrBetterIsSelected() {
        // "deploy.y" matches only the window title; the bundle doesn't match at all.
        let r = BundleSearch.rank(windows: [gmail, deploy], bundles: [acme, jobs], query: "deploy.y")
        #expect(r.items == [.window(deploy)])
        #expect(r.selection == 0)

        // Equal tier (both prefix matches): the window wins the selection, bundles stay above.
        let tie = WindowInfo.fixture(id: 4, appName: "Acme Tool", title: "x")
        let r2 = BundleSearch.rank(windows: [tie], bundles: [acme], query: "acme")
        #expect(r2.items == [.bundle(acme), .window(tie)])
        #expect(r2.selection == 1)
    }

    @Test func bundlesStayAboveWindowsEvenWhenTheWindowMatchesBetter() {
        let chromeLike = BundleSummary(id: UUID(), name: "My notes archive", openWindows: 1, files: 0)
        let r = BundleSearch.rank(windows: [notes], bundles: [chromeLike], query: "notes")
        #expect(r.items == [.bundle(chromeLike), .window(notes)])
        #expect(r.selection == 1)
    }

    @Test func bundlesAreRankedByMatchQuality() {
        let loose = BundleSummary(id: UUID(), name: "The big acme-api plan", openWindows: 0, files: 0)
        let r = BundleSearch.rank(windows: [], bundles: [loose, acme], query: "acme-api")
        #expect(r.items == [.bundle(acme), .bundle(loose)])
        #expect(r.selection == 0)
    }

    @Test func nothingMatchingSelectsZero() {
        let r = BundleSearch.rank(windows: [gmail], bundles: [acme], query: "zzzz")
        #expect(r.items.isEmpty)
        #expect(r.selection == 0)
    }

    @Test func countTextNamesOpenWindowsAndOnlyNonzeroFiles() {
        func text(_ windows: Int, _ files: Int) -> String {
            BundleSummary(id: UUID(), name: "x", openWindows: windows, files: files).countText
        }
        #expect(text(4, 0) == "4 windows")
        #expect(text(1, 0) == "1 window")
        #expect(text(0, 0) == "no open windows")
        #expect(text(4, 2) == "4 windows, 2 files")
        #expect(text(0, 1) == "no open windows, 1 file")
    }

    @Test func pickerListsAllBundlesThenANewBundleRow() {
        let r = BundleSearch.pickerRows(bundles: [acme, jobs], query: "")
        #expect(r.rows == [.bundle(acme), .bundle(jobs), .newBundle(name: "")])
        #expect(r.selection == 0)
        #expect(BundleSearch.pickerRows(bundles: [], query: "").selection == 0)
    }

    @Test func pickerFiltersByNameAndOffersTheTypedNameAsANewBundle() {
        #expect(BundleSearch.pickerRows(bundles: [jobs, acme], query: "acme").rows == [.bundle(acme), .newBundle(name: "acme")])
        let r = BundleSearch.pickerRows(bundles: [jobs, acme], query: " beam  ")
        #expect(r.rows == [.newBundle(name: "beam")])
        #expect(r.selection == 0)
    }

    @Test func pickerSelectsANewBundleUnlessABundleMatchesByPrefix() {
        // "plic" is only a substring of "Job applications": typing a name + ⏎ must create, not add to it.
        let loose = BundleSearch.pickerRows(bundles: [jobs, acme], query: "plic")
        #expect(loose.rows == [.bundle(jobs), .newBundle(name: "plic")])
        #expect(loose.selection == 1)
        // A subsequence match doesn't count either.
        #expect(BundleSearch.pickerRows(bundles: [acme], query: "cep").selection == 1)
        // Prefix, word-prefix and exact matches select the bundle.
        #expect(BundleSearch.pickerRows(bundles: [jobs, acme], query: "job").selection == 0)
        #expect(BundleSearch.pickerRows(bundles: [jobs, acme], query: "applic").selection == 0)
        #expect(BundleSearch.pickerRows(bundles: [jobs, acme], query: "acme").selection == 0)
    }

    @Test func pickerOffersNoNewBundleWhenTheNameExists() {
        let r = BundleSearch.pickerRows(bundles: [jobs, acme], query: "Acme-API")
        #expect(r.rows == [.bundle(acme)])
        #expect(r.selection == 0)
    }

    @Test func pickerRowIDsAreDistinct() {
        let rows = BundleSearch.pickerRows(bundles: [acme, jobs], query: "").rows
        #expect(Set(rows.map(\.id)).count == rows.count)
    }
}
