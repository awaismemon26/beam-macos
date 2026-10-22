import AppKit
import SwiftUI
import Vision

setbuf(stdout, nil)
func w(_ id: UInt32, _ app: String, _ title: String) -> WindowInfo {
    WindowInfo(id: id, pid: pid_t(id % 7 + 100), appName: app, appSearchNames: [app], bundleID: nil, title: title,
               isMinimized: false, spaceNumber: nil, isOnCurrentSpace: true, isReachable: true)
}
let apps = ["Microsoft Outlook", "Claude", "Code - Insiders", "Paper", "Microsoft Teams", "App Store", "Code", "Activity Monitor",
            "Podman Desktop", "draw.io", "Postman", "Bitwarden", "Calendar", "Obsidian", "iTerm2"]
var windows: [WindowInfo] = []
var nextID: UInt32 = 1000
for (i, app) in apps.enumerated() {
    windows.append(w(nextID, app, "\(app) window \(i)")); nextID += 1
    if i == 2 || i == 6 || i == 11 { windows.append(w(nextID, "Google Chrome", "Chrome tab \(i)")); nextID += 1 }
}

@MainActor final class Runner {
    let model = WindowSearchModel()
    var window: NSWindow!
    var seen = Set<ObjectIdentifier>()

    func texts(_ el: Any, depth: Int = 0, into out: inout [String]) {
        guard depth < 18, let e = el as? NSAccessibilityProtocol & AnyObject, seen.insert(ObjectIdentifier(e)).inserted else { return }
        if e.accessibilityRole() == NSAccessibility.Role.staticText,
           let v = (e.accessibilityValue() as? String) ?? e.accessibilityLabel(), !v.isEmpty { out.append(v) }
        for c in e.accessibilityChildren() ?? [] { texts(c, depth: depth + 1, into: &out) }
    }

    func start() {
        model.all = windows
        let view = WindowSearchView(model: model, onMove: { _ in }, onRecall: { _ in false }, onSubmit: {}, onCancel: {}, onActivate: { _ in },
                                    onKey: { _ in false }, onBack: {})
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 460), styleMask: [.borderless], backing: .buffered, defer: false)
        window.alphaValue = 0.01 // invisible to the user, still laid out and drawn
        window.contentView = NSHostingView(rootView: view)
        window.orderFrontRegardless()
        step(1)
    }

    func step(_ i: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            if i <= 6 {
                model.query = String("chrome".prefix(i))
                step(i + 1)
            } else {
                let view = window.contentView!
                let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
                view.cacheDisplay(in: view.bounds, to: rep)
                try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
                print("model results:", model.results.map(\.id))
                exit(0)
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let runner = MainActor.assumeIsolated { Runner() }
DispatchQueue.main.async { MainActor.assumeIsolated { runner.start() } }
app.run()
