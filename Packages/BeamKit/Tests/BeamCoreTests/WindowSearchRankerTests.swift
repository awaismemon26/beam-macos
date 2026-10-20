import Testing
@testable import BeamCore

@Suite struct WindowSearchRankerTests {
    let gmail = WindowInfo.fixture(id: 1, appName: "Google Chrome", title: "Inbox (12) - Gmail")
    let jira = WindowInfo.fixture(id: 2, appName: "Google Chrome", title: "Jira · Sprint 42")
    let code1 = WindowInfo.fixture(id: 3, appName: "Code", appSearchNames: ["Code", "Visual Studio Code"], title: "beam — AppDelegate.swift")
    let code2 = WindowInfo.fixture(id: 4, appName: "Code", appSearchNames: ["Code", "Visual Studio Code"], title: "api — main.go")
    let review = WindowInfo.fixture(id: 5, appName: "Google Chrome", title: "Code review · PR 17")

    @Test func chromeQueryReturnsAllChromeWindows() {
        let r = WindowSearchRanker.rank([gmail, code1, jira], query: "chrome")
        #expect(r.map(\.id) == [1, 2])
    }
    @Test func vscodeAliasMatchesCode() {
        let r = WindowSearchRanker.rank([gmail, code1, code2], query: "vscode")
        #expect(r.map(\.id) == [3, 4])
    }
    @Test func appMatchBeatsTitleMatch() {
        let r = WindowSearchRanker.rank([review, code1, code2], query: "code")
        #expect(r.map(\.id) == [3, 4, 5])
    }
    @Test func titleOnlyMatchIncluded() {
        let r = WindowSearchRanker.rank([gmail, code1, jira], query: "jira")
        #expect(r.map(\.id) == [2])
    }
    @Test func emptyQueryReturnsInput() {
        let r = WindowSearchRanker.rank([jira, gmail, code1], query: "  ")
        #expect(r.map(\.id) == [2, 1, 3])
    }
}
