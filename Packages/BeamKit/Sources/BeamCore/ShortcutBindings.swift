/// Beam's global shortcuts, each rebindable in Settings.
public enum ShortcutAction: String, CaseIterable, Codable, Sendable {
    case launcher, windowSearch, switcher, searchFiles, settings
}

/// The combo bound to every global shortcut; `nil` means no hotkey.
public struct ShortcutBindings: Codable, Equatable, Sendable {
    public var launcher: KeyCombo?
    public var windowSearch: KeyCombo?
    /// Hold its modifiers, tap the key to move (⇧ moves backwards), release to jump.
    public var switcher: KeyCombo?
    public var searchFiles: KeyCombo?
    public var settings: KeyCombo?

    public init(
        launcher: KeyCombo? = nil, windowSearch: KeyCombo? = nil, switcher: KeyCombo? = nil,
        searchFiles: KeyCombo? = nil, settings: KeyCombo? = nil
    ) {
        self.launcher = launcher
        self.windowSearch = windowSearch
        self.switcher = switcher
        self.searchFiles = searchFiles
        self.settings = settings
    }

    /// ⌥Space, ⌥Tab, ⌃Tab; Search Files and Settings unbound.
    public static let defaults = ShortcutBindings(
        launcher: KeyCombo(keyCode: KeyCode.space, modifiers: .option),
        windowSearch: KeyCombo(keyCode: KeyCode.tab, modifiers: .option),
        switcher: KeyCombo(keyCode: KeyCode.tab, modifiers: .control)
    )

    /// Nothing bound: used while a recorder listens, so no shortcut fires.
    public static let disabled = ShortcutBindings()

    public subscript(action: ShortcutAction) -> KeyCombo? {
        get {
            switch action {
            case .launcher: launcher
            case .windowSearch: windowSearch
            case .switcher: switcher
            case .searchFiles: searchFiles
            case .settings: settings
            }
        }
        set {
            switch action {
            case .launcher: launcher = newValue
            case .windowSearch: windowSearch = newValue
            case .switcher: switcher = newValue
            case .searchFiles: searchFiles = newValue
            case .settings: settings = newValue
            }
        }
    }
}

public enum ShortcutIssue: Equatable, Sendable {
    /// None of ⌃ ⌥ ⌘ held.
    case needsModifier
    /// ⇧ + the switcher's key moves backwards, so ⇧ can't be one of its modifiers.
    case switcherUsesShift
    /// Another Beam action already answers this combo.
    case conflict(ShortcutAction)
    /// macOS or most apps use it; allowed, with a warning.
    case systemReserved

    public var isBlocking: Bool { self != .systemReserved }
}

public enum ShortcutValidator {
    static let systemReserved: Set<KeyCombo> = [
        KeyCombo(keyCode: KeyCode.tab, modifiers: .command),
        KeyCombo(keyCode: KeyCode.space, modifiers: .command),
        KeyCombo(keyCode: 12, modifiers: .command), // Q
        KeyCombo(keyCode: 13, modifiers: .command), // W
        KeyCombo(keyCode: 4, modifiers: .command), // H
        KeyCombo(keyCode: 46, modifiers: .command), // M
        KeyCombo(keyCode: KeyCode.space, modifiers: .control),
        KeyCombo(keyCode: KeyCode.space, modifiers: [.control, .command]),
    ]

    /// Everything wrong with binding `combo` to `action`, blocking issues first.
    public static func issues(for combo: KeyCombo, action: ShortcutAction, in bindings: ShortcutBindings) -> [ShortcutIssue] {
        var issues: [ShortcutIssue] = []
        if combo.modifiers.isDisjoint(with: [.control, .option, .command]) { issues.append(.needsModifier) }
        if action == .switcher && combo.modifiers.contains(.shift) { issues.append(.switcherUsesShift) }
        let claimed = claims(combo, for: action)
        for other in ShortcutAction.allCases where other != action {
            if let bound = bindings[other], !claimed.isDisjoint(with: claims(bound, for: other)) {
                issues.append(.conflict(other))
            }
        }
        if !claimed.isDisjoint(with: systemReserved) { issues.append(.systemReserved) }
        return issues
    }

    /// At least one way into Beam must remain: the launcher shortcut or the menu-bar icon.
    public static func canClear(_ action: ShortcutAction, in bindings: ShortcutBindings, menuBarIconShown: Bool) -> Bool {
        action != .launcher || menuBarIconShown
    }

    /// The combos the classifier answers for `action`: window search and the switcher also take ⇧.
    private static func claims(_ combo: KeyCombo, for action: ShortcutAction) -> Set<KeyCombo> {
        switch action {
        case .windowSearch, .switcher:
            [combo, KeyCombo(keyCode: combo.keyCode, modifiers: combo.modifiers.union(.shift))]
        case .launcher, .searchFiles, .settings:
            [combo]
        }
    }
}
