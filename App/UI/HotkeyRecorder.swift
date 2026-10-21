import AppKit
import BeamCore
import SwiftUI

/// Click, then press a key combination with at least one modifier. Esc cancels.
struct HotkeyRecorder: View {
    @Bindable var settings: AppSettings
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button { isRecording ? stop() : start() } label: {
                Text(isRecording ? "Press keys…" : settings.rootHotkey.displayString)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(minWidth: 80, minHeight: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isRecording ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(isRecording ? Color.accentColor : .clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Click, then press a new shortcut. Esc cancels.")
            Button { settings.rootHotkey = .defaultRootSearch } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .disabled(settings.rootHotkey == .defaultRootSearch)
            .help("Reset to ⌥ Space")
        }
        .overlay(alignment: .bottomTrailing) {
            if let warning {
                Text(warning).font(.caption).foregroundStyle(.orange).fixedSize().offset(y: 18)
            }
        }
        .onDisappear { stop() }
    }

    private var warning: String? {
        switch settings.rootHotkey {
        case KeyCombo(keyCode: KeyCode.tab, modifiers: .control): "Ctrl+Tab is already the window switcher."
        case KeyCombo(keyCode: KeyCode.tab, modifiers: .option): "Option+Tab is already window search."
        default: nil
        }
    }

    private func start() {
        isRecording = true
        settings.setRecording(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == KeyCode.escape {
                stop()
                return nil
            }
            let modifiers = EventTap.modifiers(CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
            guard !modifiers.subtracting(.shift).isEmpty else { return nil }
            settings.rootHotkey = KeyCombo(keyCode: event.keyCode, modifiers: modifiers)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording { settings.setRecording(false) }
        isRecording = false
    }
}

extension KeyCombo {
    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + " " + Self.keyName(keyCode)
    }

    /// Names for the ANSI key codes people use in shortcuts.
    static func keyName(_ code: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J", 40: "K", 37: "L",
            46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W",
            7: "X", 16: "Y", 6: "Z", 29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
            28: "8", 25: "9", 49: "Space", 36: "↩", 48: "⇥", 53: "⎋", 51: "⌫", 50: "`", 27: "-", 24: "=",
            33: "[", 30: "]", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 42: "\\", 123: "←", 124: "→",
            125: "↓", 126: "↑", 122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7",
            100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        return names[code] ?? "Key \(code)"
    }
}
