import CoreGraphics
import Testing
@testable import BeamCore

@Suite struct ScreenChoiceTests {
    /// Primary on the left, a second display to its right, both in one coordinate space.
    let screens = [CGRect(x: 0, y: 0, width: 1000, height: 800), CGRect(x: 1000, y: 0, width: 1000, height: 800)]

    @Test func mouseChoosesScreenUnderMouse() {
        #expect(ScreenChoice.index(for: .mouse, screens: screens, mouse: CGPoint(x: 1500, y: 400), activeWindow: nil) == 1)
        #expect(ScreenChoice.index(for: .mouse, screens: screens, mouse: CGPoint(x: 10, y: 10), activeWindow: nil) == 0)
    }

    @Test func primaryIsIndexZero() {
        #expect(ScreenChoice.index(for: .primary, screens: screens, mouse: CGPoint(x: 1500, y: 400),
                                   activeWindow: CGRect(x: 1100, y: 100, width: 300, height: 300)) == 0)
    }

    @Test func activeWindowUsesLargestOverlap() {
        // Straddles both screens: 100 pt on the first, 300 pt on the second.
        let window = CGRect(x: 900, y: 100, width: 400, height: 300)
        #expect(ScreenChoice.index(for: .activeWindow, screens: screens, mouse: CGPoint(x: 10, y: 10), activeWindow: window) == 1)
    }

    @Test func activeWindowMissingFallsBackToMouse() {
        #expect(ScreenChoice.index(for: .activeWindow, screens: screens, mouse: CGPoint(x: 1500, y: 400), activeWindow: nil) == 1)
    }

    @Test func activeWindowOffAllScreensFallsBackToMouse() {
        let window = CGRect(x: 5000, y: 5000, width: 200, height: 200)
        #expect(ScreenChoice.index(for: .activeWindow, screens: screens, mouse: CGPoint(x: 1500, y: 400), activeWindow: window) == 1)
    }

    @Test func mouseOffAllScreensFallsBackToPrimary() {
        #expect(ScreenChoice.index(for: .mouse, screens: screens, mouse: CGPoint(x: -500, y: -500), activeWindow: nil) == 0)
        #expect(ScreenChoice.index(for: .activeWindow, screens: screens, mouse: CGPoint(x: -500, y: -500), activeWindow: nil) == 0)
    }
}
