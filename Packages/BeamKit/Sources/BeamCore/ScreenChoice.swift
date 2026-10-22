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

    /// A rectangle from CoreGraphics' space (origin at the primary display's top-left, y down) in Cocoa's
    /// (origin at its bottom-left, y up). `primaryHeight` is the primary display's height.
    public static func cocoaRect(fromCG rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func screenUnderMouse(_ screens: [CGRect], _ mouse: CGPoint) -> Int {
        // Cocoa reports the mouse on a display's top row as y == maxY, so the top edge is inclusive (and the
        // bottom exclusive), as NSMouseInRect(_, _, false) does; CGRect.contains is the other way round.
        screens.firstIndex { mouse.x >= $0.minX && mouse.x < $0.maxX && mouse.y > $0.minY && mouse.y <= $0.maxY } ?? 0
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
