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
    private static let rootHotkeyKey = "rootSearchHotkey"
    private static let showInMenuBarKey = "showInMenuBar"
    private static let appearanceKey = "appearance"

    var rootHotkey: KeyCombo {
        didSet {
            if let data = try? JSONEncoder().encode(rootHotkey) {
                UserDefaults.standard.set(data, forKey: Self.rootHotkeyKey)
            }
            onRootHotkeyChange?(rootHotkey)
        }
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

    /// Called with the combo the event tap should use (a disabled combo while recording a new one).
    var onRootHotkeyChange: ((KeyCombo) -> Void)?
    var onShowInMenuBarChange: ((Bool) -> Void)?

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.rootHotkeyKey),
           let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            rootHotkey = combo
        } else {
            rootHotkey = .defaultRootSearch
        }
        showInMenuBar = defaults.object(forKey: Self.showInMenuBarKey) as? Bool ?? true
        appearance = defaults.string(forKey: Self.appearanceKey).flatMap(AppearanceMode.init) ?? .system
    }

    /// Applies the appearance to every Beam window and panel.
    func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }

    /// While the recorder listens, the old hotkey must not open Beam.
    func setRecording(_ recording: Bool) {
        onRootHotkeyChange?(recording ? KeyCombo(keyCode: .max, modifiers: []) : rootHotkey)
    }
}
