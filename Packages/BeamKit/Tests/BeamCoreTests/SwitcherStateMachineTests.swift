import Testing
@testable import BeamCore

@Suite struct SwitcherStateMachineTests {
    @Test func firstTabHighlightsSecond() {
        var s = SwitcherStateMachine()
        #expect(s.handle(.tab(shift: false), itemCount: 3) == .open(highlight: 1))
        #expect(s.isOpen)
    }
    @Test func singleItemOpensOnFirstRow() {
        var s = SwitcherStateMachine()
        #expect(s.handle(.tab(shift: false), itemCount: 1) == .open(highlight: 0))
    }
    @Test func shiftTabOpensOnLast() {
        var s = SwitcherStateMachine()
        #expect(s.handle(.tab(shift: true), itemCount: 3) == .open(highlight: 2))
    }
    @Test func tabWraps() {
        var s = SwitcherStateMachine()
        _ = s.handle(.tab(shift: false), itemCount: 3)
        #expect(s.handle(.tab(shift: false), itemCount: 3) == .move(to: 2))
        #expect(s.handle(.tab(shift: false), itemCount: 3) == .move(to: 0))
    }
    @Test func shiftTabWrapsBackwards() {
        var s = SwitcherStateMachine()
        _ = s.handle(.tab(shift: false), itemCount: 3) // highlight 1
        #expect(s.handle(.tab(shift: true), itemCount: 3) == .move(to: 0))
        #expect(s.handle(.tab(shift: true), itemCount: 3) == .move(to: 2))
    }
    @Test func enterFocusesHighlighted() {
        var s = SwitcherStateMachine()
        _ = s.handle(.tab(shift: false), itemCount: 3)
        #expect(s.handle(.enter, itemCount: 3) == .focus(index: 1))
        #expect(s.isOpen)
    }
    @Test func zeroItemsEnterDoesNothing() {
        var s = SwitcherStateMachine()
        #expect(s.handle(.tab(shift: false), itemCount: 0) == .open(highlight: 0))
        #expect(s.handle(.enter, itemCount: 0) == .none)
        #expect(s.handle(.tab(shift: false), itemCount: 0) == .none)
    }
    @Test func controlReleaseCommitsHighlighted() {
        var s = SwitcherStateMachine()
        _ = s.handle(.tab(shift: false), itemCount: 3)
        #expect(s.handle(.controlReleased, itemCount: 3) == .commit(index: 1))
        #expect(!s.isOpen)
    }
    @Test func escapeCloses() {
        var s = SwitcherStateMachine()
        _ = s.handle(.tab(shift: false), itemCount: 3)
        #expect(s.handle(.escape, itemCount: 3) == .close)
    }
    @Test func enterWhileClosedIsNone() {
        var s = SwitcherStateMachine()
        #expect(s.handle(.enter, itemCount: 3) == .none)
    }

    @Test func resetHighlightAfterLateLoadPicksSecond() {
        var s = SwitcherStateMachine()
        _ = s.handle(.tab(shift: false), itemCount: 0)
        #expect(s.resetHighlight(itemCount: 3) == 1)
        #expect(s.handle(.enter, itemCount: 3) == .focus(index: 1))
    }
    @Test func resetHighlightWhileClosedIsZero() {
        var s = SwitcherStateMachine()
        #expect(s.resetHighlight(itemCount: 3) == 0)
        #expect(!s.isOpen)
    }

    @Test func resetHighlightAfterShiftOpenPicksLast() {
        var s = SwitcherStateMachine()
        _ = s.handle(.tab(shift: true), itemCount: 0)
        #expect(s.resetHighlight(itemCount: 3) == 2)
    }

    @Test func releaseAfterMovingCommitsHighlighted() {
        var s = SwitcherStateMachine()
        _ = s.handle(.tab(shift: false), itemCount: 3)
        _ = s.handle(.tab(shift: false), itemCount: 3)
        #expect(s.handle(.controlReleased, itemCount: 3) == .commit(index: 2))
    }
    @Test func releaseWithNoWindowsJustCloses() {
        var s = SwitcherStateMachine()
        _ = s.handle(.tab(shift: false), itemCount: 0)
        #expect(s.handle(.controlReleased, itemCount: 0) == .close)
        #expect(!s.isOpen)
    }
    @Test func releaseAfterEscapeDoesNothing() {
        var s = SwitcherStateMachine()
        _ = s.handle(.tab(shift: false), itemCount: 3)
        _ = s.handle(.escape, itemCount: 3)
        #expect(s.handle(.controlReleased, itemCount: 3) == .none)
    }
}
