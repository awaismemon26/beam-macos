import AppKit
import BeamCore
import SwiftUI

/// File search on/off and the folders it looks in.
struct FileSearchSettings: View {
    @Bindable var settings: AppSettings

    private static let home = FileManager.default.homeDirectoryForCurrentUser.path

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCard {
                SettingsRow("Enable File Search", footnote: "Type f and a space in the launcher, or use Search Files.") {
                    Toggle("", isOn: $settings.fileSearchEnabled).toggleStyle(.switch).labelsHidden()
                }
            }
            Text("macOS may ask once for access to these folders.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.leading, 4)

            SettingsSectionHeader("Folders")
            SettingsCard {
                ForEach(Array(settings.fileScopes.enumerated()), id: \.element) { index, folder in
                    if index > 0 { SettingsDivider() }
                    scopeRow(folder)
                }
                if !settings.fileScopes.isEmpty { SettingsDivider() }
                HStack {
                    Button { addFolder() } label: { Label("Add Folder…", systemImage: "plus") }
                    Spacer()
                    Button("Restore Defaults") { settings.fileScopes = AppSettings.defaultFileScopes }
                        .disabled(settings.fileScopes == AppSettings.defaultFileScopes)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
            }
        }
    }

    private func scopeRow(_ folder: String) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: folder))
                .resizable()
                .frame(width: 20, height: 20)
            Text(FilePaths.display(folder, home: Self.home))
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 16)
            Button { settings.fileScopes.removeAll { $0 == folder } } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Stop searching this folder")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose folders for File Search."
        panel.begin { response in
            guard response == .OK else { return }
            MainActor.assumeIsolated {
                for url in panel.urls where !settings.fileScopes.contains(url.path) {
                    settings.fileScopes.append(url.path)
                }
            }
        }
    }
}
