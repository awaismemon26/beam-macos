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

    /// Returns once the user has granted Accessibility access.
    static func waitUntilTrusted() async {
        while !isTrusted {
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
