/// What the switcher UI should do in response to a key.
public enum SwitcherCommand: Equatable, Sendable {
    case open(highlight: Int), move(to: Int), focus(index: Int), close, none
}

/// State of the Ctrl+Tab panel. Releasing Control closes without switching; Enter focuses.
/// The machine does not close on `.focus` — the controller closes it after a successful focus.
public struct SwitcherStateMachine: Sendable {
    public private(set) var isOpen = false
    public private(set) var highlighted = 0

    public init() {}

    public mutating func handle(_ key: SwitcherKey, itemCount: Int) -> SwitcherCommand {
        guard isOpen else {
            guard case let .tab(shift) = key else { return .none }
            isOpen = true
            highlighted = shift ? max(itemCount - 1, 0) : (itemCount > 1 ? 1 : 0)
            return .open(highlight: highlighted)
        }
        switch key {
        case let .tab(shift):
            guard itemCount > 0 else { return .none }
            highlighted = (highlighted + (shift ? -1 : 1) + itemCount) % itemCount
            return .move(to: highlighted)
        case .enter:
            return itemCount > 0 ? .focus(index: min(highlighted, itemCount - 1)) : .none
        case .escape, .controlReleased:
            isOpen = false
            highlighted = 0
            return .close
        }
    }

    /// Re-applies the opening highlight after the window list loaded late (only meaningful before the
    /// user has moved). Returns the new highlight.
    public mutating func resetHighlight(itemCount: Int) -> Int {
        highlighted = isOpen && itemCount > 1 ? 1 : 0
        return highlighted
    }
}
