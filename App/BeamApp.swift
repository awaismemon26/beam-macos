import SwiftUI

@main
struct BeamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Beam's windows are AppKit panels owned by AppDelegate; Settings opens in its own window there,
        // because SwiftUI's Settings scene can't be opened reliably from a menu-bar-only app.
        Settings { EmptyView() }
    }
}
