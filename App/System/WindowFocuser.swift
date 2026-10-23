import AppKit
import ApplicationServices
import BeamCore

enum FocusResult: Equatable {
    case focused
    /// Beam can't guarantee this exact window; nothing was changed.
    case unreachable
    /// The focus calls ran but another window ended up focused (logged for diagnosis).
    case mismatch
}

/// Brings one exact window to the front, across apps and Desktops, the way Raycast/AltTab do:
/// SkyLight "set front process for window" + a synthetic "make key window" event + AX raise.
/// Not main-actor bound: AX calls block for up to the messaging timeout when the target app is busy.
enum WindowFocuser {
    /// kCPSUserGenerated: treat the activation as user-initiated so macOS switches Desktops.
    private static let userGenerated: UInt32 = 0x200
    private static let verifyAttempts = 8
    private static let verifyInterval: Duration = .milliseconds(50)
    private static let stackingDelay: Duration = .milliseconds(40)

    static func focus(_ window: WindowInfo, element: AXRef?) async -> FocusResult {
        guard let element, front(window, element: element) else { return .unreachable }

        // Desktop switches animate, so poll briefly before declaring a mismatch.
        var lastSeen: CGWindowID?
        for _ in 0..<verifyAttempts {
            try? await Task.sleep(for: verifyInterval)
            lastSeen = focusedWindowID()
            if lastSeen == window.id { return .focused }
        }
        log.error("Focus mismatch: wanted \(window.id) got \(lastSeen ?? 0)")
        return .mismatch
    }

    /// Un-minimizes `window`, unhides its app, and makes its app frontmost with this window raised and key.
    /// Returns false when the window can't be targeted (nothing was changed). Doesn't wait for the result.
    private static func front(_ window: WindowInfo, element: AXRef) -> Bool {
        guard window.isReachable,
              let getProcessForPID = PrivateAPIs.getProcessForPID,
              let setFrontProcess = PrivateAPIs.setFrontProcessWithOptions,
              let postEventRecord = PrivateAPIs.postEventRecordTo
        else { return false }

        var psn = ProcessSerialNumber()
        guard getProcessForPID(window.pid, &psn) == noErr else { return false }

        let ax = element.element
        restore(window, ax)
        _ = setFrontProcess(&psn, window.id, userGenerated)
        makeKeyWindow(psn: &psn, windowID: window.id, post: postEventRecord)
        AXUIElementPerformAction(ax, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(ax, kAXMainAttribute as CFString, kCFBooleanTrue)
        return true
    }

    private static func restore(_ window: WindowInfo, _ ax: AXUIElement) {
        if window.isMinimized {
            AXUIElementSetAttributeValue(ax, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        if let app = NSRunningApplication(processIdentifier: window.pid), app.isHidden {
            app.unhide()
        }
    }

    /// Brings a bundle's windows forward without moving any between Desktops (macOS has no reliable way to).
    /// Oldest first, each member on the current Desktop brings its app to the front with that window raised, so
    /// windows of different apps all end up above other apps; members on other Desktops are un-minimized and raised
    /// where they are, without switching to them. Finally `last` — the most recently used — is focused (and verified)
    /// the usual way, switching to its Desktop if needed.
    @discardableResult
    static func bringForward(
        _ windows: [WindowInfo], focusing last: WindowInfo, elements: @Sendable (CGWindowID) -> AXRef?
    ) async -> FocusResult {
        for window in windows.reversed() where window.id != last.id && window.isReachable {
            guard let element = elements(window.id) else { continue }
            if window.isOnCurrentSpace {
                guard front(window, element: element) else { continue }
                // Let the WindowServer apply this activation before the next one, so the stacking order holds.
                try? await Task.sleep(for: stackingDelay)
            } else {
                restore(window, element.element)
                AXUIElementPerformAction(element.element, kAXRaiseAction as CFString)
            }
        }
        return await focus(last, element: elements(last.id))
    }

    /// Two synthetic event records (0x01 then 0x02) that tell the WindowServer to make `windowID` key.
    private static func makeKeyWindow(
        psn: inout ProcessSerialNumber, windowID: CGWindowID, post: PrivateAPIs.PostEventRecordTo
    ) {
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        withUnsafeBytes(of: windowID) { idBytes in
            for (offset, byte) in idBytes.enumerated() { bytes[0x3c + offset] = byte }
        }
        for offset in 0x20..<0x30 { bytes[offset] = 0xff }

        bytes[0x08] = 0x01
        _ = post(&psn, &bytes)
        bytes[0x08] = 0x02
        _ = post(&psn, &bytes)
    }

    /// The `CGWindowID` of the frontmost app's focused window.
    static func focusedWindowID() -> CGWindowID? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        return focusedWindowID(ofPID: pid)
    }

    static func focusedWindowID(ofPID pid: pid_t) -> CGWindowID? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, WindowEnumerator.messagingTimeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return PrivateAPIs.windowID(of: value as! AXUIElement)
    }
}
