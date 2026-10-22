import AppKit
import BeamCore
import SwiftUI

/// Click, then press a key combination for `action`. Esc cancels; a combo Beam can't honour is refused with the reason.
struct HotkeyRecorder: View {
    let action: ShortcutAction
    @Bindable var settings: AppSettings
    @State private var isRecording = false
    @State private var monitor: Any?
    /// Why the last attempt was refused; the next attempt clears it.
    @State private var rejection: ShortcutIssue?

    private var combo: KeyCombo? { settings.shortcuts[action] }
    private var canClear: Bool {
        ShortcutValidator.canClear(action, in: settings.shortcuts, menuBarIconShown: settings.showInMenuBar)
    }

    /// A refused attempt, else what is wrong with the saved combo (a migrated or edited one can still clash).
    private var issue: ShortcutIssue? {
        if let rejection { return rejection }
        guard let combo else { return nil }
        let issues = ShortcutValidator.issues(for: combo, action: action, in: settings.shortcuts)
        return issues.first(where: \.isBlocking) ?? issues.first
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Button { isRecording ? stop() : start() } label: {
                    Text(isRecording ? "Press keys…" : combo?.displayString ?? "None")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(combo == nil && !isRecording ? .secondary : .primary)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 96, minHeight: 24)
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
                iconButton("arrow.counterclockwise", help: "Reset to default", enabled: combo != ShortcutBindings.defaults[action]) {
                    stop()
                    apply(ShortcutBindings.defaults[action])
                }
                iconButton("xmark", help: canClear ? "Clear shortcut" : "Keep at least one way to open Beam",
                           enabled: combo != nil && canClear) {
                    stop()
                    rejection = nil
                    settings.shortcuts[action] = nil
                }
            }
            if let issue, !isRecording {
                Text(issue.message).font(.caption).foregroundStyle(issue.isBlocking ? .red : .orange)
            }
        }
        .onDisappear { stop() }
    }

    private func iconButton(_ name: String, help: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .help(help)
    }

    /// Saves `combo` unless it has a blocking issue; a macOS clash is saved and shown as a warning.
    private func apply(_ combo: KeyCombo?) {
        if let combo,
           let blocking = ShortcutValidator.issues(for: combo, action: action, in: settings.shortcuts).first(where: \.isBlocking) {
            rejection = blocking
            return
        }
        rejection = nil
        settings.shortcuts[action] = combo
    }

    private func start() {
        rejection = nil
        isRecording = true
        settings.setRecording(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == KeyCode.escape {
                stop()
                return nil
            }
            let modifiers = EventTap.modifiers(CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
            stop()
            apply(KeyCombo(keyCode: event.keyCode, modifiers: modifiers))
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

extension ShortcutAction {
    var title: String {
        switch self {
        case .launcher: "Launcher"
        case .windowSearch: "Window search"
        case .switcher: "Window switcher"
        case .searchFiles: "Search Files"
        case .settings: "Beam Settings"
        }
    }
}

extension ShortcutIssue {
    var message: String {
        switch self {
        case .needsModifier: "Use at least one of ⌃ ⌥ ⌘"
        case .switcherUsesShift: "⇧ moves backwards, so it can't be a modifier here"
        case .switcherKeyReserved: "⏎ and ⎋ are used while the switcher is open"
        case let .conflict(other): "Already used by \(other.title)"
        case .systemReserved: "Also used by macOS"
        }
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

extension KeyCombo {
    /// The same combo as an `NSMenuItem` key equivalent (for display in a menu), if the key has one.
    var menuKeyEquivalent: (key: String, mask: NSEvent.ModifierFlags)? {
        let name = Self.keyName(keyCode)
        let key: String
        switch name {
        case "Space": key = " "
        case "⇥": key = "\t"
        case "↩": key = "\r"
        case "⎋": key = "\u{1B}"
        case "⌫": key = "\u{8}"
        case "←": key = String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case "→": key = String(UnicodeScalar(NSRightArrowFunctionKey)!)
        case "↓": key = String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case "↑": key = String(UnicodeScalar(NSUpArrowFunctionKey)!)
        case _ where name.count > 1 && name.hasPrefix("F") && Int(name.dropFirst()) != nil:
            key = String(UnicodeScalar(NSF1FunctionKey + Int(name.dropFirst())! - 1)!)
        case _ where name.count == 1: key = name.lowercased()
        default: return nil
        }
        var mask: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) { mask.insert(.control) }
        if modifiers.contains(.option) { mask.insert(.option) }
        if modifiers.contains(.shift) { mask.insert(.shift) }
        if modifiers.contains(.command) { mask.insert(.command) }
        return (key, mask)
    }
}
