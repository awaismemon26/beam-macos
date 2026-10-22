import Foundation
import Testing
@testable import BeamCore

@Suite struct BundleMatcherTests {
    static let code = "com.microsoft.VSCode"
    let flagsmith = WindowInfo.fixture(id: 1, bundleID: code, title: "azure-pipelines.yml — flagsmith")
    let flagsmithAPI = WindowInfo.fixture(id: 2, bundleID: code, title: "main.go — flagsmith-api")
    let mentions = WindowInfo.fixture(id: 3, bundleID: code, title: "flagsmith-notes.md — other")
    let otherApp = WindowInfo.fixture(id: 4, bundleID: "com.apple.dt.Xcode", title: "flagsmith — Foo.swift")
    let chrome = WindowInfo.fixture(id: 5, bundleID: "com.google.Chrome", title: "Flagsmith docs")

    func rule(_ app: String?, _ key: String, _ match: BundleRule.Match, session: UInt32? = nil) -> BundleRule {
        BundleRule(appBundleID: app, key: key, match: match, sessionWindowID: session)
    }

    @Test func exactRuleMatchesItsOwnWindow() {
        #expect(BundleMatcher.matches(BundleMatcher.rule(for: flagsmith), flagsmith))
    }

    @Test func exactRuleIsNotFooledByLongerOrMerelyContainingTitles() {
        let r = BundleMatcher.rule(for: flagsmith)
        #expect(!BundleMatcher.matches(r, flagsmithAPI))
        #expect(!BundleMatcher.matches(r, mentions))
    }

    @Test func exactRuleIsCaseInsensitive() {
        let r = rule(Self.code, "FlagSmith", .exact)
        #expect(BundleMatcher.matches(r, flagsmith))
    }

    @Test func sameKeyInAnotherAppDoesNotMatch() {
        let r = BundleMatcher.rule(for: flagsmith)
        #expect(!BundleMatcher.matches(r, otherApp))
    }

    @Test func containsRuleMatchesSubstringsCaseInsensitively() {
        let r = rule(Self.code, "FLAGSMITH", .contains)
        #expect(BundleMatcher.matches(r, flagsmith))
        #expect(BundleMatcher.matches(r, flagsmithAPI))
        #expect(BundleMatcher.matches(r, mentions))
        #expect(!BundleMatcher.matches(r, otherApp))
    }

    @Test func anyAppContainsRuleMatchesAcrossApps() {
        let r = rule(nil, "flagsmith", .contains)
        #expect(BundleMatcher.matches(r, flagsmith))
        #expect(BundleMatcher.matches(r, otherApp))
        #expect(BundleMatcher.matches(r, chrome))
    }

    @Test func emptyKeyMatchesNothing() {
        #expect(!BundleMatcher.matches(rule(nil, "", .contains), flagsmith))
        #expect(!BundleMatcher.matches(rule(Self.code, "", .exact), flagsmith))
    }

    @Test func sessionRuleMatchesOnlyItsWindowID() {
        let r = BundleMatcher.rule(for: chrome)
        #expect(BundleMatcher.matches(r, chrome))
        let reopened = WindowInfo.fixture(id: 99, bundleID: "com.google.Chrome", title: "Flagsmith docs")
        #expect(!BundleMatcher.matches(r, reopened))
    }

    @Test func windowWhoseTitleMovedAwayLeavesTheBundle() {
        let r = BundleMatcher.rule(for: flagsmith)
        let moved = WindowInfo.fixture(id: 1, bundleID: Self.code, title: "azure-pipelines.yml — elsewhere")
        #expect(!BundleMatcher.matches(r, moved))
    }

    @Test func ruleForWindowIsExactWithExtractedKey() {
        let r = BundleMatcher.rule(for: flagsmith)
        #expect(r == rule(Self.code, "flagsmith", .exact))
    }

    @Test func ruleForWindowWithoutKeyIsASessionRule() {
        let r = BundleMatcher.rule(for: chrome)
        #expect(r.sessionWindowID == 5)
        #expect(r.appBundleID == "com.google.Chrome")
    }

    @Test func windowsOfBundleKeepInputOrderAndMatchAnyRule() {
        let bundle = BeamBundle(
            id: UUID(), name: "flagsmith",
            rules: [BundleMatcher.rule(for: chrome), BundleMatcher.rule(for: flagsmith)],
            files: [], savedSearches: []
        )
        let found = BundleMatcher.windows(of: bundle, in: [chrome, flagsmithAPI, flagsmith, otherApp])
        #expect(found.map(\.id) == [5, 1])
    }
}
