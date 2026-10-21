/// What the switcher UI should do in response to a key.
public enum SwitcherCommand: Equatable, Sendable {
    case open(highlight: Int), move(to: Int), focus(index: Int), close, none
    /// Close the panel and focus this row (Control was released, like Cmd+Tab).
    case commit(index: Int)
}

/// State of the Ctrl+Tab panel. Releasing Control switches to the highlighted window; Esc cancels;
/// Enter focuses without waiting for the release. The machine does not close on `.focus` — the
/// controller closes it after a successful focus.
public struct SwitcherStateMachine: Sendable {
    public private(set) var isOpen = false
    public private(set) var highlighted = 0
    private var openedBackwards = false

    public init() {}

    public mutating func handle(_ key: SwitcherKey, itemCount: Int) -> SwitcherCommand {
        guard isOpen else {
            guard case let .tab(shift) = key else { return .none }
            isOpen = true
            openedBackwards = shift
            highlighted = Self.openingHighlight(backwards: shift, itemCount: itemCount)
            return .open(highlight: highlighted)
        }
        switch key {
        case let .tab(shift):
            guard itemCount > 0 else { return .none }
            highlighted = (highlighted + (shift ? -1 : 1) + itemCount) % itemCount
            return .move(to: highlighted)
        case .enter:
            return itemCount > 0 ? .focus(index: min(highlighted, itemCount - 1)) : .none
        case .escape:
            isOpen = false
            highlighted = 0
            return .close
        case .controlReleased:
            let index = min(highlighted, itemCount - 1)
            isOpen = false
            highlighted = 0
            return itemCount > 0 ? .commit(index: index) : .close
        }
    }

    /// Re-applies the opening highlight after the window list loaded late (only meaningful before the
    /// user has moved). Returns the new highlight.
    public mutating func resetHighlight(itemCount: Int) -> Int {
        highlighted = isOpen ? Self.openingHighlight(backwards: openedBackwards, itemCount: itemCount) : 0
        return highlighted
    }

    /// Ctrl+Tab starts on the previous window; Ctrl+Shift+Tab on the last one.
    private static func openingHighlight(backwards: Bool, itemCount: Int) -> Int {
        backwards ? max(itemCount - 1, 0) : (itemCount > 1 ? 1 : 0)
    }
}
