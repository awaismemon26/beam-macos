import AppKit
import BeamCore

/// Resolves the "Show Beam on" setting to a concrete display, at the moment a panel opens.
@MainActor
enum PanelScreens {
    static func screen(for choice: PanelScreen) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        // The active window is only looked up when it is the setting; the mouse case costs nothing.
        let window = choice == .activeWindow ? activeWindowFrame() : nil
        let index = ScreenChoice.index(
            for: choice, screens: screens.map(\.frame), mouse: NSEvent.mouseLocation, activeWindow: window)
        return screens[index]
    }

    /// The frontmost app's top window in Cocoa coordinates. Read from the window server list, not
    /// Accessibility, so opening a panel stays instant.
    private static func activeWindowFrame() -> CGRect? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]],
              let primary = NSScreen.screens.first
        else { return nil }
        for entry in list {
            guard (entry[kCGWindowOwnerPID as String] as? Int32) == pid,
                  (entry[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  !rect.isEmpty
            else { continue }
            // CG puts the origin at the primary display's top-left; Cocoa at its bottom-left.
            return CGRect(x: rect.minX, y: primary.frame.height - rect.maxY, width: rect.width, height: rect.height)
        }
        return nil
    }
}
