import BeamCore
import SwiftUI

/// The big search field at the top of Beam's search panels, with list-navigation keys.
struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    /// Changing this value focuses the field (bumped every time the panel is shown).
    let focusTrigger: Int
    let onMove: (Int) -> Void
    /// ↑/↓ only (not Tab): offered first, for history recall; returns whether it used the key.
    var onRecall: ((Int) -> Bool)?
    let onSubmit: () -> Void
    let onCancel: () -> Void
    var onCommandComma: (() -> Void)?
    /// A label shown before the text, naming the panel's current mode (e.g. `Search Files`).
    var chip: String?
    /// The panel's own keys (⌘⏎, ⌘G, ⇧⌘G, ⌘⌫, ←, →, ⌫ on an empty field); returns whether it used the key.
    /// Unused keys keep their usual meaning (⌘⏎ submits, the rest edit the text).
    var onKey: ((PanelKey) -> Bool)?

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
            if let chip {
                Text(chip)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.1)))
                    .fixedSize()
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($focused)
                .onKeyPress(.downArrow) { arrow(1); return .handled }
                .onKeyPress(.upArrow) { arrow(-1); return .handled }
                .onKeyPress(keys: [.tab]) { press in
                    onMove(press.modifiers.contains(.shift) ? -1 : 1)
                    return .handled
                }
                .onKeyPress(keys: [.return]) { press in
                    if press.modifiers.contains(.command), send(.commandReturn) { return .handled }
                    onSubmit()
                    return .handled
                }
                .onKeyPress(.escape) { onCancel(); return .handled }
                .onKeyPress(keys: [","]) { press in
                    guard press.modifiers.contains(.command), let onCommandComma else { return .ignored }
                    onCommandComma()
                    return .handled
                }
                .onKeyPress(keys: ["g", "G"]) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    return send(press.modifiers.contains(.shift) ? .saveSearchToBundle : .addToBundle) ? .handled : .ignored
                }
                // ⌫ arrives as U+007F (DEL) on macOS; `.delete` alone is U+0008.
                .onKeyPress(keys: [.delete, KeyEquivalent("\u{7F}")]) { press in
                    if press.modifiers.contains(.command) { return send(.removeFromBundle) ? .handled : .ignored }
                    return text.isEmpty && send(.backspaceOnEmpty) ? .handled : .ignored
                }
                .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
                    // ⌘←, ⇧← etc. still move the caret. (Arrow keys always carry the function/keypad flags.)
                    guard press.modifiers.isDisjoint(with: [.command, .option, .control, .shift]) else { return .ignored }
                    return send(press.key == .leftArrow ? .left : .right) ? .handled : .ignored
                }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .onChange(of: focusTrigger, initial: true) { focused = true }
    }

    private func arrow(_ delta: Int) {
        if onRecall?(delta) == true { return }
        onMove(delta)
    }

    private func send(_ key: PanelKey) -> Bool {
        onKey?(key) ?? false
    }
}
