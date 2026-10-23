import BeamCore
import SwiftUI

/// Every global shortcut with its recorder, then the fixed keys inside Beam's panels for reference.
struct ShortcutsSettings: View {
    @Bindable var settings: AppSettings

    private static let panelKeys: [(keys: String, meaning: String)] = [
        ("↑ ↓", "Select"),
        ("⏎", "Open"),
        ("⌘ ⏎", "Open / bring all forward"),
        ("⌘ G", "Add to bundle"),
        ("⇧ ⌘ G", "Save search to bundle"),
        ("⌘ ⌫", "Remove from bundle"),
        ("⎋", "Close"),
    ]

    /// The Search Files shortcut does nothing while File Search is off.
    private func isUnavailable(_ action: ShortcutAction) -> Bool {
        action == .searchFiles && !settings.fileSearchEnabled
    }

    private func footnote(for action: ShortcutAction) -> String? {
        switch action {
        case .switcher: "Hold the modifier, tap the key to move, release to switch."
        case .searchFiles where !settings.fileSearchEnabled: "Turn on File Search to use this shortcut."
        default: nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCard {
                ForEach(Array(ShortcutAction.allCases.enumerated()), id: \.element) { index, action in
                    if index > 0 { SettingsDivider() }
                    SettingsRow(action.title, footnote: footnote(for: action)) {
                        HotkeyRecorder(action: action, settings: settings)
                            .disabled(isUnavailable(action))
                    }
                    .opacity(isUnavailable(action) ? 0.5 : 1)
                }
            }

            SettingsSectionHeader("In panels")
            SettingsCard {
                ForEach(Array(Self.panelKeys.enumerated()), id: \.offset) { index, key in
                    if index > 0 { SettingsDivider() }
                    SettingsRow(key.meaning) {
                        Text(key.keys)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 24)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.06)))
                    }
                }
            }
        }
    }
}
