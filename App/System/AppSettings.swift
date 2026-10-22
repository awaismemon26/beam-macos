import AppKit
import BeamCore
import Foundation
import Observation

/// How Beam's windows look: follow macOS, or always light/dark.
enum AppearanceMode: String, CaseIterable, Sendable {
    case system, light, dark

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// User preferences persisted in UserDefaults.
@MainActor @Observable
final class AppSettings {
    private static let shortcutsKey = "shortcuts"
    /// 1.0 stored only the launcher combo; read once to migrate, then left in place.
    private static let legacyRootHotkeyKey = "rootSearchHotkey"
    private static let showInMenuBarKey = "showInMenuBar"
    private static let appearanceKey = "appearance"
    private static let panelScreenKey = "panelScreen"
    private static let showCalculatorKey = "showCalculator"
    private static let fileSearchEnabledKey = "fileSearchEnabled"
    private static let fileScopesKey = "fileScopes"

    var shortcuts: ShortcutBindings {
        didSet {
            Self.save(shortcuts)
            onShortcutsChange?(activeShortcuts)
            onShortcutsEdited?(shortcuts)
        }
    }

    /// The bindings that should fire: the Search Files shortcut only while File Search is on, so a combo saved
    /// earlier doesn't swallow its keys while it can do nothing.
    var activeShortcuts: ShortcutBindings {
        var active = shortcuts
        if !fileSearchEnabled { active.searchFiles = nil }
        return active
    }

    var showInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showInMenuBar, forKey: Self.showInMenuBarKey)
            onShowInMenuBarChange?(showInMenuBar)
        }
    }

    var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
            applyAppearance()
        }
    }

    /// Which display the launcher, window search and switcher open on.
    var panelScreen: PanelScreen {
        didSet { UserDefaults.standard.set(panelScreen.rawValue, forKey: Self.panelScreenKey) }
    }

    /// Whether the launcher evaluates what you type as a calculation.
    var showCalculator: Bool {
        didSet { UserDefaults.standard.set(showCalculator, forKey: Self.showCalculatorKey) }
    }

    /// File search in the launcher (`f …`, Search Files). Off by default: turning it on may make macOS ask for
    /// folder access, which must not happen on first run.
    var fileSearchEnabled: Bool {
        didSet {
            UserDefaults.standard.set(fileSearchEnabled, forKey: Self.fileSearchEnabledKey)
            if recordingAction == nil { onShortcutsChange?(activeShortcuts) }
        }
    }

    /// Folders File Search looks in. Saved only while they differ from the defaults.
    var fileScopes: [String] {
        didSet {
            if fileScopes == Self.defaultFileScopes {
                UserDefaults.standard.removeObject(forKey: Self.fileScopesKey)
            } else {
                UserDefaults.standard.set(fileScopes, forKey: Self.fileScopesKey)
            }
        }
    }

    static var defaultFileScopes: [String] {
        FileScopes.defaults(home: FileManager.default.homeDirectoryForCurrentUser.path)
    }

    /// The action whose recorder is listening, if any. One at a time; while it is set no global shortcut fires,
    /// and the real bindings return exactly once, when it goes back to nil.
    var recordingAction: ShortcutAction? {
        didSet {
            guard (oldValue == nil) != (recordingAction == nil) else { return }
            onShortcutsChange?(recordingAction == nil ? activeShortcuts : .disabled)
        }
    }

    /// Called with the bindings the event tap should use (`.disabled` while recording a new one).
    var onShortcutsChange: ((ShortcutBindings) -> Void)?
    /// Called with the saved bindings after every edit (not while recording), for anything that displays them.
    var onShortcutsEdited: ((ShortcutBindings) -> Void)?
    var onShowInMenuBarChange: ((Bool) -> Void)?

    init() {
        let defaults = UserDefaults.standard
        shortcuts = Self.loadShortcuts(defaults)
        showInMenuBar = defaults.object(forKey: Self.showInMenuBarKey) as? Bool ?? true
        appearance = defaults.string(forKey: Self.appearanceKey).flatMap(AppearanceMode.init) ?? .system
        panelScreen = defaults.string(forKey: Self.panelScreenKey).flatMap(PanelScreen.init) ?? .mouse
        showCalculator = defaults.object(forKey: Self.showCalculatorKey) as? Bool ?? true
        fileSearchEnabled = defaults.bool(forKey: Self.fileSearchEnabledKey)
        fileScopes = defaults.stringArray(forKey: Self.fileScopesKey) ?? Self.defaultFileScopes
    }

    /// Applies the appearance to every Beam window and panel.
    func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }

    private static func loadShortcuts(_ defaults: UserDefaults) -> ShortcutBindings {
        if let data = defaults.data(forKey: shortcutsKey),
           let bindings = try? JSONDecoder().decode(ShortcutBindings.self, from: data) {
            return bindings.sanitized
        }
        var bindings = ShortcutBindings.defaults
        if let data = defaults.data(forKey: legacyRootHotkeyKey),
           let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            bindings.launcher = combo
            bindings = bindings.sanitized
            save(bindings)
        }
        return bindings
    }

    private static func save(_ bindings: ShortcutBindings) {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: shortcutsKey)
        }
    }
}
