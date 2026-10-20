import SwiftUI

enum Theme {
    static let cornerRadius: CGFloat = 14
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let rootSize = CGSize(width: 750, height: 475)
    static let switcherMaxWidth: CGFloat = 640
    static let switcherMinWidth: CGFloat = 420
    static let rowHeight: CGFloat = 36
    static let maxVisibleSwitcherRows = 10
    static let rowCornerRadius: CGFloat = 8
    static let iconSize: CGFloat = 20
}

/// The HUD material behind every Beam panel.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Wraps panel content in the rounded HUD chrome.
struct PanelChrome<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(VisualEffectBackground())
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
    }
}

/// Small horizontal shake used when Enter is pressed on a window Beam can't reach.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 6
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}
