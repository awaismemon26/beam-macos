import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General", shortcuts = "Shortcuts", launcher = "Launcher", calculator = "Calculator"
    case fileSearch = "File Search", bundles = "Bundles", about = "About"

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .general: "gearshape.fill"
        case .shortcuts: "command"
        case .launcher: "magnifyingglass"
        case .calculator: "plus.forwardslash.minus"
        case .fileSearch: "doc.text.magnifyingglass"
        case .bundles: "square.stack.3d.up.fill"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .shortcuts: .orange
        case .launcher: .blue
        case .calculator: .green
        case .fileSearch: .teal
        case .bundles: .pink
        case .about: .indigo
        }
    }
}

/// Currency-rate status shown in Calculator; closures keep the view independent of the calculator engine.
struct RatesStatus {
    let lastUpdate: () async -> Date?
    let refresh: () async -> Void
}

/// Raycast-style settings: a sidebar of panes, each a column of grouped cards.
struct SettingsView: View {
    @Bindable var settings: AppSettings
    let history: HistoryStore
    let bundles: BundleStore
    let rates: RatesStatus
    @State private var pane: SettingsPane

    init(settings: AppSettings, history: HistoryStore, bundles: BundleStore, rates: RatesStatus, initialPane: SettingsPane = .general) {
        self.settings = settings
        self.history = history
        self.bundles = bundles
        self.rates = rates
        _pane = State(initialValue: initialPane)
    }

    static let size = CGSize(width: 760, height: 500)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().ignoresSafeArea()
            ScrollView {
                Group {
                    switch pane {
                    case .general: GeneralSettings(settings: settings)
                    case .shortcuts: ShortcutsSettings(settings: settings)
                    case .launcher: LauncherSettings(settings: settings, history: history)
                    case .calculator: CalculatorSettings(settings: settings, rates: rates)
                    case .fileSearch: FileSearchSettings(settings: settings)
                    case .bundles: BundlesSettings(store: bundles, settings: settings)
                    case .about: AboutSettings()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
        }
        // Fill the window: with a full-size content view it is taller than the requested content size.
        .frame(minWidth: Self.size.width, maxWidth: .infinity, minHeight: Self.size.height, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsPane.allCases) { item in
                Button { pane = item } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(item.tint.gradient))
                        Text(item.rawValue).font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(pane == item ? Color.primary.opacity(0.1) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 52) // clear the traffic lights
        .frame(width: 210)
        .frame(maxHeight: .infinity)
        .background(SidebarMaterial())
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Bindable var settings: AppSettings
    @State private var openAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    /// The icon stays while the Launcher has no shortcut: one way into Beam must remain.
    private var menuBarFootnote: String? {
        if !settings.showInMenuBar { return "Open Settings with ⌘, in Beam, or by opening Beam again." }
        return settings.shortcuts.launcher == nil ? "Needed while the Launcher has no shortcut." : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCard {
                SettingsRow("Open at Login") {
                    Toggle("", isOn: $openAtLogin).toggleStyle(.switch).labelsHidden()
                        .onChange(of: openAtLogin) { _, on in
                            guard on != LoginItem.isEnabled else { return }
                            do { try LoginItem.set(on); loginError = nil } catch {
                                loginError = error.localizedDescription
                                openAtLogin = LoginItem.isEnabled
                            }
                        }
                }
                SettingsDivider()
                SettingsRow("Show in Menu Bar", footnote: menuBarFootnote) {
                    Toggle("", isOn: $settings.showInMenuBar).toggleStyle(.switch).labelsHidden()
                        .disabled(settings.showInMenuBar && settings.shortcuts.launcher == nil)
                }
            }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red).padding(.top, 6)
            }

            SettingsSectionHeader("Appearance")
            SettingsCard {
                SettingsRow("Follow System Appearance") {
                    Toggle("", isOn: Binding(
                        get: { settings.appearance == .system },
                        set: { follow in
                            settings.appearance = follow ? .system : Self.currentSystemMode
                        }
                    ))
                    .toggleStyle(.switch).labelsHidden()
                }
                if settings.appearance != .system {
                    SettingsDivider()
                    SettingsRow("Appearance") {
                        Picker("", selection: $settings.appearance) {
                            Text("Light").tag(AppearanceMode.light)
                            Text("Dark").tag(AppearanceMode.dark)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 140)
                    }
                }
            }
        }
        .animation(Theme.spring, value: settings.appearance == .system)
        .task {
            // The login item can also be changed in System Settings ▸ General ▸ Login Items.
            while !Task.isCancelled {
                openAtLogin = LoginItem.isEnabled
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    /// When the user stops following macOS, keep what they currently see.
    private static var currentSystemMode: AppearanceMode {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }
}

// MARK: - About

private struct AboutSettings: View {
    @State private var isTrusted = Permissions.isTrusted

    private static let repositoryURL = URL(string: "https://github.com/awaismemon26/beam-macos")!
    private static let issuesURL = URL(string: "https://github.com/awaismemon26/beam-macos/issues/new/choose")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Beam").font(.system(size: 22, weight: .semibold))
                    Text("Version \(Self.version)").foregroundStyle(.secondary)
                    Text("Every window, one keystroke away.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 20)

            SettingsCard {
                SettingsRow("Accessibility") {
                    if isTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                    }
                }
            }

            SettingsSectionHeader("Links")
            SettingsCard {
                SettingsRow("Source Code") { Link("GitHub", destination: Self.repositoryURL) }
                SettingsDivider()
                SettingsRow("Feedback") { Link("Report an issue", destination: Self.issuesURL) }
            }
        }
        .task {
            while !Task.isCancelled {
                isTrusted = Permissions.isTrusted
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

// MARK: - Building blocks

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.07))
            )
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let footnote: String?
    @ViewBuilder let control: Control

    init(_ title: String, footnote: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.footnote = footnote
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let footnote {
                    Text(footnote).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 16)
            control
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider().padding(.leading, 14)
    }
}

struct SettingsSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .padding(.top, 24)
            .padding(.bottom, 10)
            .padding(.leading, 4)
    }
}

/// The translucent sidebar background used by System Settings.
private struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
