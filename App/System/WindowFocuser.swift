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
@MainActor
enum WindowFocuser {
    /// kCPSUserGenerated: treat the activation as user-initiated so macOS switches Desktops.
    private static let userGenerated: UInt32 = 0x200
    private static let verifyAttempts = 8
    private static let verifyInterval: Duration = .milliseconds(50)

    static func focus(_ window: WindowInfo, element: AXRef?) async -> FocusResult {
        guard window.isReachable, let element,
              let getProcessForPID = PrivateAPIs.getProcessForPID,
              let setFrontProcess = PrivateAPIs.setFrontProcessWithOptions,
              let postEventRecord = PrivateAPIs.postEventRecordTo
        else { return .unreachable }

        var psn = ProcessSerialNumber()
        guard getProcessForPID(window.pid, &psn) == noErr else { return .unreachable }

        let ax = element.element
        if window.isMinimized {
            AXUIElementSetAttributeValue(ax, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        if let app = NSRunningApplication(processIdentifier: window.pid), app.isHidden {
            app.unhide()
        }

        _ = setFrontProcess(&psn, window.id, userGenerated)
        makeKeyWindow(psn: &psn, windowID: window.id, post: postEventRecord)
        AXUIElementPerformAction(ax, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(ax, kAXMainAttribute as CFString, kCFBooleanTrue)

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
