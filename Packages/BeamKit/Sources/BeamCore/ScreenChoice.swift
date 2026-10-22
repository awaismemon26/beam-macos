import CoreGraphics

/// Which display Beam's panels open on.
public enum PanelScreen: String, CaseIterable, Codable, Sendable {
    case mouse, activeWindow, primary
}

/// Picks the display for a panel. Pure: callers pass every screen frame in one coordinate space, primary first.
public enum ScreenChoice {
    /// Index into `screens`. The active window's screen is the one it overlaps most; with no window, or one
    /// off every screen, the mouse decides; a mouse off every screen falls back to the primary (index 0).
    public static func index(for choice: PanelScreen, screens: [CGRect], mouse: CGPoint, activeWindow: CGRect?) -> Int {
        switch choice {
        case .primary:
            return 0
        case .mouse:
            return screenUnderMouse(screens, mouse)
        case .activeWindow:
            if let activeWindow, let best = largestOverlap(screens, activeWindow) { return best }
            return screenUnderMouse(screens, mouse)
        }
    }

    private static func screenUnderMouse(_ screens: [CGRect], _ mouse: CGPoint) -> Int {
        screens.firstIndex { $0.contains(mouse) } ?? 0
    }

    private static func largestOverlap(_ screens: [CGRect], _ window: CGRect) -> Int? {
        var best: (index: Int, area: CGFloat)?
        for (index, screen) in screens.enumerated() {
            let overlap = screen.intersection(window)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > 0, area > (best?.area ?? 0) { best = (index, area) }
        }
        return best?.index
    }
}
