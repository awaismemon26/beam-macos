import Testing
@testable import BeamCore

@Test func untitledFallback() {
    #expect(WindowInfo.fixture(appName: "Code", title: "").displayTitle == "Code — untitled")
}

@Test func minimizedBadgeWins() {
    #expect(WindowInfo.fixture(isMinimized: true, spaceNumber: 2, isOnCurrentSpace: false).badge == "Minimized")
}

@Test func otherDesktopBadge() {
    #expect(WindowInfo.fixture(spaceNumber: 2, isOnCurrentSpace: false).badge == "Desktop 2")
}

@Test func currentDesktopHasNoBadge() {
    #expect(WindowInfo.fixture(spaceNumber: 1, isOnCurrentSpace: true).badge == nil)
}
