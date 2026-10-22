import BeamCore
import SwiftUI

/// Where the panels open and the recent searches kept for ↑.
struct LauncherSettings: View {
    @Bindable var settings: AppSettings

    private static let screenTitles: [(PanelScreen, String)] = [
        (.mouse, "Screen containing mouse"),
        (.activeWindow, "Screen with active window"),
        (.primary, "Primary screen"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCard {
                SettingsRow("Show Beam on") {
                    Picker("", selection: $settings.panelScreen) {
                        ForEach(Self.screenTitles, id: \.0) { choice, title in Text(title).tag(choice) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsDivider()
                SettingsRow("Search History", footnote: "Clears recent searches restored with ↑ in the launcher and window search.") {
                    // Wired once search history exists.
                    Button("Clear") {}.disabled(true)
                }
            }
        }
    }
}
