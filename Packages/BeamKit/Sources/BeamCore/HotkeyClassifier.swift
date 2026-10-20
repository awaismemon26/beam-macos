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

    /// Option+Space.
    public static let defaultRootSearch = KeyCombo(keyCode: KeyCode.space, modifiers: .option)
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

/// Keys the Ctrl+Tab switcher reacts to.
public enum SwitcherKey: Equatable, Sendable {
    case tab(shift: Bool), enter, escape, controlReleased
}

public enum HotkeyAction: Equatable, Sendable {
    case pass, swallow, reenableTap
    /// Forwarded to the switcher. Swallowed, except `.controlReleased`, whose flagsChanged event passes through.
    case switcher(SwitcherKey)
    case openWindowSearch
    case toggleRootSearch
}

/// Decides, synchronously on the event-tap thread, what to do with each keyboard event.
public struct HotkeyClassifier: Sendable {
    public var rootSearch: KeyCombo
    public var isSwitcherOpen = false
    /// Key codes whose keyDown was swallowed; their keyUp is swallowed too, whatever the modifiers then.
    private var swallowedDowns: Set<UInt16> = []

    public init(rootSearch: KeyCombo = .defaultRootSearch) {
        self.rootSearch = rootSearch
    }

    public mutating func classify(_ event: RawKeyEvent) -> HotkeyAction {
        switch event {
        case .tapDisabled:
            return .reenableTap

        case let .keyDown(keyCode, mods, isRepeat):
            let action = classifyKeyDown(keyCode: keyCode, mods: mods, isRepeat: isRepeat)
            if action != .pass { swallowedDowns.insert(keyCode) }
            // Track open/closed here, synchronously, so a quick Control release can't race the UI.
            switch action {
            case .switcher(.tab): isSwitcherOpen = true
            case .switcher(.escape): isSwitcherOpen = false
            default: break
            }
            return action

        case let .keyUp(keyCode, _):
            return swallowedDowns.remove(keyCode) != nil ? .swallow : .pass

        case let .flagsChanged(mods):
            if isSwitcherOpen && !mods.contains(.control) {
                isSwitcherOpen = false
                return .switcher(.controlReleased)
            }
            return .pass
        }
    }

    private func classifyKeyDown(keyCode: UInt16, mods: KeyModifiers, isRepeat: Bool) -> HotkeyAction {
        if keyCode == KeyCode.tab {
            if mods.contains(.control) && mods.isDisjoint(with: [.command, .option]) {
                return .switcher(.tab(shift: mods.contains(.shift)))
            }
            if mods == .option || mods == [.option, .shift] {
                return isRepeat ? .swallow : .openWindowSearch
            }
        }
        if keyCode == rootSearch.keyCode && mods == rootSearch.modifiers {
            return isRepeat ? .swallow : .toggleRootSearch
        }
        if isSwitcherOpen {
            switch keyCode {
            case KeyCode.returnKey, KeyCode.keypadEnter: return .switcher(.enter)
            case KeyCode.escape: return .switcher(.escape)
            default: return .swallow
            }
        }
        return .pass
    }
}
