/// Modifier keys relevant to Beam's hotkeys.
public struct KeyModifiers: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = KeyModifiers(rawValue: 1 << 0)
    public static let option = KeyModifiers(rawValue: 1 << 1)
    public static let shift = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)
}

/// A virtual key code plus the exact modifiers that must be held.
public struct KeyCombo: Hashable, Codable, Sendable {
    public var keyCode: UInt16
    public var modifiers: KeyModifiers

    public init(keyCode: UInt16, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum KeyCode {
    public static let tab: UInt16 = 48
    public static let returnKey: UInt16 = 36
    public static let keypadEnter: UInt16 = 76
    public static let escape: UInt16 = 53
    public static let space: UInt16 = 49
}

/// A keyboard event as seen by the event tap, reduced to what Beam needs.
public enum RawKeyEvent: Sendable {
    case keyDown(keyCode: UInt16, modifiers: KeyModifiers, isRepeat: Bool)
    case keyUp(keyCode: UInt16, modifiers: KeyModifiers)
    case flagsChanged(modifiers: KeyModifiers)
    /// macOS disabled the tap (timeout or user input); it must be re-enabled.
    case tapDisabled
}

/// Keys the switcher (⌃Tab by default) reacts to.
public enum SwitcherKey: Equatable, Sendable {
    /// The switcher's key; `shift` moves backwards.
    case tab(shift: Bool), enter, escape
    /// One of the switcher's held modifiers was released.
    case controlReleased
}

public enum HotkeyAction: Equatable, Sendable {
    case pass, swallow, reenableTap
    /// Forwarded to the switcher. Swallowed, except `.controlReleased`, whose flagsChanged event passes through.
    case switcher(SwitcherKey)
    case openWindowSearch
    case toggleRootSearch
    case openSearchFiles
    case openSettings
}

/// Decides, synchronously on the event-tap thread, what to do with each keyboard event.
public struct HotkeyClassifier: Sendable {
    public var bindings: ShortcutBindings
    public var isSwitcherOpen = false
    /// Key codes whose keyDown was swallowed; their keyUp is swallowed too, whatever the modifiers then.
    private var swallowedDowns: Set<UInt16> = []

    public init(bindings: ShortcutBindings = .defaults) {
        self.bindings = bindings
    }

    public mutating func classify(_ event: RawKeyEvent) -> HotkeyAction {
        switch event {
        case .tapDisabled:
            return .reenableTap

        case let .keyDown(keyCode, mods, isRepeat):
            // A modifier's release was missed (the tap was disabled at the time): close and let the key through.
            if isSwitcherOpen && !holdsSwitcherModifiers(mods) {
                isSwitcherOpen = false
                swallowedDowns.remove(keyCode)
                return .switcher(.controlReleased)
            }
            let action = classifyKeyDown(keyCode: keyCode, mods: mods, isRepeat: isRepeat)
            if action == .pass {
                swallowedDowns.remove(keyCode) // a stale entry whose keyUp was lost must not eat this one
            } else {
                swallowedDowns.insert(keyCode)
            }
            // Track open/closed here, synchronously, so a quick modifier release can't race the UI.
            switch action {
            case .switcher(.tab): isSwitcherOpen = true
            case .switcher(.escape): isSwitcherOpen = false
            default: break
            }
            return action

        case let .keyUp(keyCode, _):
            return swallowedDowns.remove(keyCode) != nil ? .swallow : .pass

        case let .flagsChanged(mods):
            if isSwitcherOpen && !holdsSwitcherModifiers(mods) {
                isSwitcherOpen = false
                return .switcher(.controlReleased)
            }
            return .pass
        }
    }

    /// The binding for `action` unless it is unusable (see `ShortcutBindings.sanitized`).
    private func combo(_ action: ShortcutAction) -> KeyCombo? {
        bindings[action].flatMap { $0.isUsable(for: action) ? $0 : nil }
    }

    /// The switcher stays open while every one of its modifiers is held. Unbound, it never stays open.
    private func holdsSwitcherModifiers(_ mods: KeyModifiers) -> Bool {
        guard let switcher = combo(.switcher) else { return false }
        return mods.isSuperset(of: switcher.modifiers)
    }

    private func classifyKeyDown(keyCode: UInt16, mods: KeyModifiers, isRepeat: Bool) -> HotkeyAction {
        let switcher = combo(.switcher)
        // The switcher and window search answer with or without ⇧; the others need their exact modifiers.
        if let switcher, keyCode == switcher.keyCode, mods.subtracting(.shift) == switcher.modifiers {
            return .switcher(.tab(shift: mods.contains(.shift)))
        }
        // While the switcher is open nothing else may fire: only Return, Escape and its own key count.
        if isSwitcherOpen {
            switch keyCode {
            case KeyCode.returnKey, KeyCode.keypadEnter: return .switcher(.enter)
            case KeyCode.escape: return .switcher(.escape)
            default: return .swallow
            }
        }
        if let search = combo(.windowSearch), keyCode == search.keyCode,
           mods == search.modifiers || mods == search.modifiers.union(.shift) {
            return isRepeat ? .swallow : .openWindowSearch
        }
        let exact: [(KeyCombo?, HotkeyAction)] = [
            (combo(.launcher), .toggleRootSearch), (combo(.searchFiles), .openSearchFiles), (combo(.settings), .openSettings),
        ]
        for case let (combo?, action) in exact where keyCode == combo.keyCode && mods == combo.modifiers {
            return isRepeat ? .swallow : action
        }
        return .pass
    }
}
