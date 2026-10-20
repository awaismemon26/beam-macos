import BeamCore
import Foundation
import Observation

/// User preferences persisted in UserDefaults.
@MainActor @Observable
final class AppSettings {
    private static let rootHotkeyKey = "rootSearchHotkey"

    var rootHotkey: KeyCombo {
        didSet {
            if let data = try? JSONEncoder().encode(rootHotkey) {
                UserDefaults.standard.set(data, forKey: Self.rootHotkeyKey)
            }
            onRootHotkeyChange?(rootHotkey)
        }
    }

    /// Called with the combo the event tap should use (a disabled combo while recording a new one).
    var onRootHotkeyChange: ((KeyCombo) -> Void)?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.rootHotkeyKey),
           let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) {
            rootHotkey = combo
        } else {
            rootHotkey = .defaultRootSearch
        }
    }

    /// While the recorder listens, the old hotkey must not open Beam.
    func setRecording(_ recording: Bool) {
        onRootHotkeyChange?(recording ? KeyCombo(keyCode: .max, modifiers: []) : rootHotkey)
    }
}
