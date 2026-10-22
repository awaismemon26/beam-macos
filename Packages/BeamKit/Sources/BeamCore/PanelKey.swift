/// Keys Beam's search panels give meaning to beyond typing, ↑/↓, ⏎ and Esc. Fixed; not rebindable.
public enum PanelKey: Sendable {
    /// ⌘⏎
    case commandReturn
    /// ⌘G
    case addToBundle
    /// ⇧⌘G
    case saveSearchToBundle
    /// ⌘⌫
    case removeFromBundle
    /// ←
    case left
    /// →
    case right
    /// ⌫ while the field is empty
    case backspaceOnEmpty
}
