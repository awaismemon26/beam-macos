import Foundation
import Testing
@testable import BeamCore

@Suite struct BundleFileTests {
    let rule = BundleRule(appBundleID: "com.microsoft.VSCode", key: "flagsmith", match: .exact)
    let session = BundleRule(appBundleID: "com.google.Chrome", key: "Docs", match: .exact, sessionWindowID: 7)

    @Test func roundTripsWithVersionOne() throws {
        let bundle = BeamBundle(name: "flagsmith", rules: [rule], files: ["/tmp/a.txt"], savedSearches: ["awais cv"])
        let data = try JSONEncoder().encode(BundleFile(bundles: [bundle]))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["version"] as? Int == 1)
        #expect(BundleFile.decode(data)?.bundles == [bundle])
    }

    @Test func unreadableOrNewerFilesDoNotDecode() {
        #expect(BundleFile.decode(Data("not json".utf8)) == nil)
        #expect(BundleFile.decode(Data(#"{"bundles":"oops"}"#.utf8)) == nil)
        #expect(BundleFile.decode(Data(#"{"version":2,"bundles":[]}"#.utf8)) == nil)
        #expect(BundleFile.decode(Data(#"{"version":1,"bundles":[]}"#.utf8))?.bundles == [])
    }

    @Test func sessionRulesAreDroppedForDisk() {
        let bundle = BeamBundle(name: "x", rules: [rule, session])
        #expect(BundleFile(bundles: [bundle]).withoutSessionRules().bundles.first?.rules == [rule])
    }
}
