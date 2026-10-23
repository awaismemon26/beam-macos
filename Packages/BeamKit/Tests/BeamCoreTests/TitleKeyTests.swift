import Testing
@testable import BeamCore

@Suite struct TitleKeyTests {
    @Test(arguments: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"])
    func vsCodeUsesTheFolderPart(bundleID: String) {
        #expect(TitleKey.extract(appBundleID: bundleID, title: "azure-pipelines.yml — acme-api") == "acme-api")
        #expect(TitleKey.extract(appBundleID: bundleID, title: "acme-api") == "acme-api")
        #expect(TitleKey.extract(appBundleID: bundleID, title: "aie (Workspace)") == "aie")
        #expect(TitleKey.extract(appBundleID: bundleID, title: "● main.swift — beam") == "beam")
    }

    @Test func vsCodeProfileSuffixDoesNotBecomeTheKey() {
        let code = "com.microsoft.VSCode"
        #expect(TitleKey.extract(appBundleID: code, title: "main.swift — beam — Work") == "beam")
        #expect(TitleKey.extract(appBundleID: code, title: "● main.swift — beam — Work") == "beam")
        #expect(TitleKey.extract(appBundleID: code, title: "main.swift — aie (Workspace) — Work") == "aie")
    }

    @Test func vsCodeDirtyMarkerIsIgnoredWithoutAFolder() {
        let code = "com.microsoft.VSCode"
        #expect(TitleKey.extract(appBundleID: code, title: "● notes.md") == "notes.md")
        #expect(TitleKey.extract(appBundleID: code, title: "● notes.md") == TitleKey.extract(appBundleID: code, title: "notes.md"))
    }

    @Test(arguments: ["com.microsoft.Excel", "com.microsoft.Powerpoint", "com.microsoft.Word"])
    func officeUsesTheFileName(bundleID: String) {
        #expect(TitleKey.extract(appBundleID: bundleID, title: "Budget.xlsx") == "Budget")
        #expect(TitleKey.extract(appBundleID: bundleID, title: "Budget") == "Budget")
        #expect(TitleKey.extract(appBundleID: bundleID, title: "Budget 2025.xlsx") == "Budget 2025")
    }

    @Test func versionDotsAreNotExtensions() {
        let word = "com.microsoft.Word"
        #expect(TitleKey.extract(appBundleID: word, title: "Plan 1.2") == "Plan 1.2")
        #expect(TitleKey.extract(appBundleID: word, title: "Plan 1.3") == "Plan 1.3")
        #expect(TitleKey.extract(appBundleID: word, title: "Budget 2025.1") == "Budget 2025.1")
        #expect(TitleKey.extract(appBundleID: word, title: "report.v2") == "report.v2")
        #expect(TitleKey.extract(appBundleID: "com.apple.Preview", title: "cv 2.1 – Page 1 of 3") == "cv 2.1")
        #expect(TitleKey.extract(appBundleID: word, title: "Budget.xlsx") == "Budget")
        #expect(TitleKey.extract(appBundleID: word, title: "Plan 1.2.docx") == "Plan 1.2")
    }

    @Test func previewDropsExtensionAndPageInfo() {
        #expect(TitleKey.extract(appBundleID: "com.apple.Preview", title: "cv.pdf – Page 1 of 3") == "cv")
        #expect(TitleKey.extract(appBundleID: "com.apple.Preview", title: "cv.pdf") == "cv")
    }

    @Test func xcodeUsesTheProjectName() {
        #expect(TitleKey.extract(appBundleID: "com.apple.dt.Xcode", title: "Beam — RootSearchView.swift") == "Beam")
    }

    @Test func textEditDropsExtensionAndEditedMarker() {
        #expect(TitleKey.extract(appBundleID: "com.apple.TextEdit", title: "notes.txt — Edited") == "notes")
    }

    @Test func finderUsesTheFolderName() {
        #expect(TitleKey.extract(appBundleID: "com.apple.finder", title: "Projects") == "Projects")
    }

    @Test func browsersAndUnknownAppsHaveNoKey() {
        #expect(TitleKey.extract(appBundleID: "com.google.Chrome", title: "Inbox (12) - Gmail") == nil)
        #expect(TitleKey.extract(appBundleID: "com.apple.Safari", title: "Apple") == nil)
        #expect(TitleKey.extract(appBundleID: nil, title: "Whatever") == nil)
    }

    @Test func emptyTitleHasNoKey() {
        #expect(TitleKey.extract(appBundleID: "com.microsoft.VSCode", title: "") == nil)
        #expect(TitleKey.extract(appBundleID: "com.apple.finder", title: "   ") == nil)
    }
}
