import AppKit
import SwiftUI

/// A borderless, non-activating floating panel. Created once at launch and only shown/hidden afterwards,
/// so a hotkey never pays for window construction.
@MainActor
final class BeamPanel: NSPanel {
    private let acceptsKeyboard: Bool
    private let fitsContent: Bool
    private var hostingView: NSView?

    /// Called when the panel stops being key (e.g. the user clicked elsewhere).
    var onResignKey: (() -> Void)?

    /// - Parameters:
    ///   - size: fixed size, or the maximum size when `fitsContent` is true.
    ///   - acceptsKeyboard: whether the panel becomes key (search panels) or not (Ctrl+Tab switcher).
    ///   - fitsContent: resize to the SwiftUI content's fitting size on every `present()`.
    init(size: CGSize, acceptsKeyboard: Bool, fitsContent: Bool = false) {
        self.acceptsKeyboard = acceptsKeyboard
        self.fitsContent = fitsContent
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        isMovable = false
        becomesKeyOnlyIfNeeded = !acceptsKeyboard
    }

    override var canBecomeKey: Bool { acceptsKeyboard }
    override var canBecomeMain: Bool { false }

    func host<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: PanelChrome { view })
        hosting.sizingOptions = fitsContent ? [.intrinsicContentSize] : []
        contentView = hosting
        hostingView = hosting
    }

    /// Shows the panel centred horizontally, in the upper third of the screen under the mouse.
    func present() {
        if fitsContent, let hostingView {
            hostingView.layoutSubtreeIfNeeded()
            setContentSize(hostingView.fittingSize)
        }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = frame.size
            let origin = NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.maxY - visible.height * 0.22 - size.height
            )
            setFrameOrigin(NSPoint(x: origin.x.rounded(), y: max(origin.y, visible.minY).rounded()))
        }
        orderFrontRegardless()
        if acceptsKeyboard { makeKey() }
    }

    /// Re-fits the size while visible, keeping the top edge fixed.
    func refit() {
        guard fitsContent, let hostingView else { return }
        hostingView.layoutSubtreeIfNeeded()
        let newSize = hostingView.fittingSize
        let top = frame.maxY
        let midX = frame.midX
        setFrame(NSRect(x: (midX - newSize.width / 2).rounded(), y: (top - newSize.height).rounded(),
                        width: newSize.width, height: newSize.height), display: true)
    }

    func dismiss() {
        orderOut(nil)
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
