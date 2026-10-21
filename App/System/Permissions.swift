import AppKit
import ApplicationServices

@MainActor
enum Permissions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Adds Beam to the Accessibility list (unchecked) so the user only has to flip the switch.
    static func promptOnce() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Clears every Accessibility entry macOS holds for Beam's bundle ID (stale ones from older builds
    /// stay "on" in System Settings but don't match this build), then re-adds this build, unchecked.
    /// Returns false when `tccutil` refused.
    static func resetAndPrompt() async -> Bool {
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.beam.Beam"
        let ok = await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", "Accessibility", bundleID]
            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
        promptOnce()
        openAccessibilitySettings()
        return ok
    }

    /// Returns once the user has granted Accessibility access.
    static func waitUntilTrusted() async {
        while !isTrusted {
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
