import Foundation
import Testing
@testable import BeamCore

@Suite struct FileQueryTests {
    @Test func fPrefixYieldsTerms() {
        #expect(FileQuery.prefixedTerms("f awais cv") == "awais cv")
        #expect(FileQuery.prefixedTerms("f   cv ") == "cv")
    }

    @Test func bareFIsNotFileQuery() {
        #expect(FileQuery.prefixedTerms("f") == nil)
        #expect(FileQuery.prefixedTerms("f ") == nil)
        #expect(FileQuery.prefixedTerms("f   ") == nil)
        #expect(FileQuery.prefixedTerms("figma") == nil)
    }

    @Test func onlyLowercaseFIsThePrefix() {
        #expect(FileQuery.prefixedTerms("F cv") == nil)
    }

    @Test func termsSplitOnWhitespace() {
        #expect(FileQuery.terms("  awais \t cv\n") == ["awais", "cv"])
        #expect(FileQuery.terms("   ").isEmpty)
    }

    @Test func predicateHasOneClausePerTermCaseAndDiacriticInsensitive() {
        let p = FileQuery.predicateFormat(terms: ["awais", "cv"])
        #expect(p.format.components(separatedBy: "kMDItemFSName LIKE[cd] %@").count == 3)
        #expect(p.arguments == ["*awais*", "*cv*"])
        #expect(p.format.contains("&&"))
    }

    /// Only `*` and `\` are special in Spotlight's LIKE; `?` is a literal character there and stays unescaped.
    @Test func predicateEscapesWildcardsAndQuotes() {
        let p = FileQuery.predicateFormat(terms: [#"a*b?"c\"#])
        #expect(p.arguments == [#"*a\*b?"c\\*"#])
    }

    @Test func rankerOrdersByLastUsedThenModifiedThenName() {
        let d = { (s: TimeInterval) in Date(timeIntervalSince1970: s) }
        let usedNew = FileResult(path: "/a/z", name: "z", lastUsed: d(300), modified: d(1))
        let usedOld = FileResult(path: "/a/y", name: "y", lastUsed: d(200), modified: d(900))
        let modNew = FileResult(path: "/a/x", name: "x", lastUsed: nil, modified: d(500))
        let modOld = FileResult(path: "/a/w", name: "w", lastUsed: nil, modified: d(400))
        let nameB = FileResult(path: "/a/b", name: "b", lastUsed: nil, modified: nil)
        let nameA = FileResult(path: "/a/a", name: "A", lastUsed: nil, modified: nil)
        let sorted = FileRanker.sorted([nameB, modOld, usedOld, nameA, modNew, usedNew])
        #expect(sorted == [usedNew, usedOld, modNew, modOld, nameA, nameB])
    }

    @Test func nameMatchesEveryTermIgnoringCaseDiacriticsAndOrder() {
        #expect(FileQuery.nameMatches("CV - Awais Memon - German.pdf", terms: ["awais", "cv"]))
        #expect(FileQuery.nameMatches("Résumé.pdf", terms: ["resume"]))
        #expect(!FileQuery.nameMatches("CV - Awais Memon - German.pdf", terms: ["awais", "french"]))
        #expect(FileQuery.nameMatches("anything", terms: []))
    }

    @Test func displayAbbreviatesHomeAndNamesICloudDrive() {
        let home = "/Users/x"
        #expect(FilePaths.display("/Users/x/Downloads", home: home) == "~/Downloads")
        #expect(FilePaths.display("/Users/x", home: home) == "~")
        #expect(FilePaths.display("/Users/x/Library/Mobile Documents/com~apple~CloudDocs", home: home) == "iCloud Drive")
        #expect(FilePaths.display("/Users/x/Library/Mobile Documents/com~apple~CloudDocs/Downloads", home: home)
            == "iCloud Drive/Downloads")
        #expect(FilePaths.display("/Users/xy/Downloads", home: home) == "/Users/xy/Downloads")
        #expect(FilePaths.display("/Volumes/Disk/Work", home: home) == "/Volumes/Disk/Work")
    }

    @Test func folderIsTheParentForDisplay() {
        #expect(FilePaths.folder(of: "/Users/x/Downloads/CV.pdf") == "/Users/x/Downloads")
        #expect(FilePaths.folder(of: "/CV.pdf") == "/")
    }

    @Test func defaultScopesAreTheFiveFolders() {
        #expect(FileScopes.defaults(home: "/Users/x") == [
            "/Users/x/Desktop",
            "/Users/x/Documents",
            "/Users/x/Downloads",
            "/Users/x/Pictures",
            "/Users/x/Library/Mobile Documents/com~apple~CloudDocs",
        ])
    }
}
