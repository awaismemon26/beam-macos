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

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
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
                .onKeyPress(.return) { onSubmit(); return .handled }
                .onKeyPress(.escape) { onCancel(); return .handled }
                .onKeyPress(keys: [","]) { press in
                    guard press.modifiers.contains(.command), let onCommandComma else { return .ignored }
                    onCommandComma()
                    return .handled
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
}
