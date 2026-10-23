import Foundation
import Testing
@testable import BeamCore

@Suite struct BundleMatcherTests {
    static let code = "com.microsoft.VSCode"
    let acme = WindowInfo.fixture(id: 1, bundleID: code, title: "deploy.yml — acme-api")
    let acmeDocs = WindowInfo.fixture(id: 2, bundleID: code, title: "main.go — acme-api-docs")
    let mentions = WindowInfo.fixture(id: 3, bundleID: code, title: "acme-api-notes.md — other")
    let otherApp = WindowInfo.fixture(id: 4, bundleID: "com.apple.dt.Xcode", title: "acme-api — Foo.swift")
    let chrome = WindowInfo.fixture(id: 5, bundleID: "com.google.Chrome", title: "Acme-API docs")

    func rule(_ app: String?, _ key: String, _ match: BundleRule.Match, session: UInt32? = nil) -> BundleRule {
        BundleRule(appBundleID: app, key: key, match: match, sessionWindowID: session)
    }

    @Test func exactRuleMatchesItsOwnWindow() {
        #expect(BundleMatcher.matches(BundleMatcher.rule(for: acme), acme))
    }

    @Test func exactRuleIsNotFooledByLongerOrMerelyContainingTitles() {
        let r = BundleMatcher.rule(for: acme)
        #expect(!BundleMatcher.matches(r, acmeDocs))
        #expect(!BundleMatcher.matches(r, mentions))
    }

    @Test func exactRuleIsCaseInsensitive() {
        let r = rule(Self.code, "Acme-API", .exact)
        #expect(BundleMatcher.matches(r, acme))
    }

    @Test func sameKeyInAnotherAppDoesNotMatch() {
        let r = BundleMatcher.rule(for: acme)
        #expect(!BundleMatcher.matches(r, otherApp))
    }

    @Test func containsRuleMatchesSubstringsCaseInsensitively() {
        let r = rule(Self.code, "ACME-API", .contains)
        #expect(BundleMatcher.matches(r, acme))
        #expect(BundleMatcher.matches(r, acmeDocs))
        #expect(BundleMatcher.matches(r, mentions))
        #expect(!BundleMatcher.matches(r, otherApp))
    }

    @Test func anyAppContainsRuleMatchesAcrossApps() {
        let r = rule(nil, "acme-api", .contains)
        #expect(BundleMatcher.matches(r, acme))
        #expect(BundleMatcher.matches(r, otherApp))
        #expect(BundleMatcher.matches(r, chrome))
    }

    @Test func blankKeyMatchesNothing() {
        for key in [" ", "  ", "\t", " \n"] {
            for match in [BundleRule.Match.contains, .exact] {
                for window in [acme, acmeDocs, mentions, otherApp, chrome] {
                    #expect(!BundleMatcher.matches(rule(nil, key, match), window))
                    #expect(!BundleMatcher.matches(rule(Self.code, key, match), window))
                }
            }
        }
    }

    @Test func emptyKeyMatchesNothing() {
        #expect(!BundleMatcher.matches(rule(nil, "", .contains), acme))
        #expect(!BundleMatcher.matches(rule(Self.code, "", .exact), acme))
    }

    @Test func sessionRuleMatchesOnlyItsWindowID() {
        let r = BundleMatcher.rule(for: chrome)
        #expect(BundleMatcher.matches(r, chrome))
        let reopened = WindowInfo.fixture(id: 99, bundleID: "com.google.Chrome", title: "Acme-API docs")
        #expect(!BundleMatcher.matches(r, reopened))
    }

    @Test func windowWhoseTitleMovedAwayLeavesTheBundle() {
        let r = BundleMatcher.rule(for: acme)
        let moved = WindowInfo.fixture(id: 1, bundleID: Self.code, title: "deploy.yml — elsewhere")
        #expect(!BundleMatcher.matches(r, moved))
    }

    @Test func ruleForWindowIsExactWithExtractedKey() {
        let r = BundleMatcher.rule(for: acme)
        #expect(r == rule(Self.code, "acme-api", .exact))
    }

    @Test func ruleForWindowWithoutKeyIsASessionRule() {
        let r = BundleMatcher.rule(for: chrome)
        #expect(r.sessionWindowID == 5)
        #expect(r.appBundleID == "com.google.Chrome")
    }

    @Test func windowsOfBundleKeepInputOrderAndMatchAnyRule() {
        let bundle = BeamBundle(
            id: UUID(), name: "acme-api",
            rules: [BundleMatcher.rule(for: chrome), BundleMatcher.rule(for: acme)],
            files: [], savedSearches: []
        )
        let found = BundleMatcher.windows(of: bundle, in: [chrome, acmeDocs, acme, otherApp])
        #expect(found.map(\.id) == [5, 1])
    }

    @Test func removableRulesAreOnlyTheWindowsOwn() {
        let own = BundleMatcher.rule(for: acme)
        let session = rule(Self.code, "x", .exact, session: acme.id)
        let otherSession = rule(Self.code, "x", .exact, session: 99)
        let contains = rule(Self.code, "acme-api", .contains)
        let anyApp = rule(nil, "acme-api", .exact)
        let otherKey = rule(Self.code, "acme-api-docs", .exact)
        let otherAppRule = rule("com.apple.dt.Xcode", "acme-api", .exact)
        let bundle = BeamBundle(name: "b", rules: [own, session, otherSession, contains, anyApp, otherKey, otherAppRule])
        #expect(BundleMatcher.removableRules(for: acme, in: bundle) == [own, session])
        // Only in the bundle through broad rules: nothing to remove.
        #expect(BundleMatcher.removableRules(for: acme, in: BeamBundle(name: "c", rules: [contains, anyApp])).isEmpty)
        // Case-insensitive like matching.
        let shouty = rule(Self.code, "ACME-API", .exact)
        #expect(BundleMatcher.removableRules(for: acme, in: BeamBundle(name: "d", rules: [shouty])) == [shouty])
    }
}
