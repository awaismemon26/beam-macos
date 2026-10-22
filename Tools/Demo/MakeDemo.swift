// Renders Beam's real SwiftUI panels offscreen with sample data and assembles the README demo GIF.
// Built and run by Tools/Demo/run.sh; everything shown is made-up sample data.

import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

setbuf(stdout, nil)
let outputPath = CommandLine.arguments[1]
let logo = NSImage(contentsOfFile: CommandLine.arguments[2])?.cgImage(forProposedRect: nil, context: nil, hints: nil)

// MARK: - Sample data

let canvas = CGSize(width: 1000, height: 640)   // GIF size in pixels
let renderScale: CGFloat = 2                     // panels are rendered at Retina scale, then scaled down

func icon(_ path: String) -> NSImage? {
    FileManager.default.fileExists(atPath: path) ? NSWorkspace.shared.icon(forFile: path) : nil
}

let appPaths: [String: String] = [
    "Safari": "/Applications/Safari.app", "Calendar": "/System/Applications/Calendar.app",
    "Calculator": "/System/Applications/Calculator.app", "Notes": "/System/Applications/Notes.app",
    "Mail": "/System/Applications/Mail.app", "Music": "/System/Applications/Music.app",
    "Terminal": "/System/Applications/Utilities/Terminal.app", "Xcode": "/Applications/Xcode.app",
    "Finder": "/System/Library/CoreServices/Finder.app", "Maps": "/System/Applications/Maps.app",
    "Photos": "/System/Applications/Photos.app", "System Settings": "/System/Applications/System Settings.app",
]
let appPIDs: [String: pid_t] = Dictionary(uniqueKeysWithValues: appPaths.keys.sorted().enumerated().map { ($1, pid_t(500 + $0)) })
var iconsByPID: [pid_t: NSImage] = [:]
for (name, path) in appPaths { if let image = icon(path) { iconsByPID[appPIDs[name]!] = image } }
func demoIcon(_ pid: pid_t) -> NSImage? { iconsByPID[pid] }

func app(_ name: String) -> AppEntry { AppEntry(id: appPaths[name]!, name: name, bundleID: nil) }

var nextWindowID: UInt32 = 1
func window(_ appName: String, _ title: String, minimized: Bool = false, desktop: Int? = nil) -> WindowInfo {
    defer { nextWindowID += 1 }
    return WindowInfo(id: nextWindowID, pid: appPIDs[appName]!, appName: appName, appSearchNames: [appName], bundleID: nil,
                      title: title, isMinimized: minimized, spaceNumber: desktop ?? 1, isOnCurrentSpace: desktop == nil,
                      isReachable: true)
}

let safariWindows = [
    window("Safari", "Beam — a fast, native window switcher"),
    window("Safari", "Release notes – Beam 1.0.0"),
    window("Safari", "SwiftUI — Apple Developer Documentation", desktop: 2),
    window("Safari", "Weekend trip ideas", minimized: true),
]
let allWindows = [
    safariWindows[0],
    window("Xcode", "Beam — RootSearchView.swift"),
    window("Notes", "Meeting notes — Q4 planning"),
    window("Terminal", "~/Projects/beam — zsh"),
    safariWindows[1],
    window("Mail", "Inbox — 3 unread"),
    window("Notes", "Grocery list"),
    window("Xcode", "Beam — WindowFocuser.swift", desktop: 2),
    safariWindows[2],
    window("Calendar", "Calendar"),
    window("Music", "Music"),
    safariWindows[3],
]

// MARK: - Rendering

@MainActor
final class PanelRenderer {
    let window: NSWindow
    private let fitsContent: Bool

    /// `size` nil: the panel sizes itself to its content (the switcher).
    init<V: View>(_ view: V, size: CGSize?) {
        fitsContent = size == nil
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size ?? CGSize(width: 600, height: 400)),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.alphaValue = 0.01
        window.contentView = NSHostingView(rootView: view)
        window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
        window.orderFrontRegardless()
    }

    /// Lets SwiftUI apply pending state, then captures the panel at Retina scale.
    func capture() async -> CGImage {
        try? await Task.sleep(for: .milliseconds(120))
        let view = window.contentView!
        if fitsContent {
            view.layoutSubtreeIfNeeded()
            window.setContentSize(view.fittingSize)
            try? await Task.sleep(for: .milliseconds(60))
        }
        view.layoutSubtreeIfNeeded()
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width * renderScale),
                                   pixelsHigh: Int(view.bounds.height * renderScale), bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.cgImage!
    }
}

// MARK: - Compositing

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

let wallpaper: CGImage = {
    let ctx = CGContext(data: nil, width: Int(canvas.width), height: Int(canvas.height), bitsPerComponent: 8, bytesPerRow: 0,
                        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let colors = [CGColor(red: 0.07, green: 0.09, blue: 0.24, alpha: 1), CGColor(red: 0.30, green: 0.14, blue: 0.45, alpha: 1),
                  CGColor(red: 0.85, green: 0.42, blue: 0.38, alpha: 1)] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.6, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: canvas.height), end: CGPoint(x: canvas.width, y: 0), options: [])
    // Soft glows.
    for (x, y, r, c) in [(180.0, 520.0, 260.0, CGColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.35)),
                         (820.0, 140.0, 300.0, CGColor(red: 1, green: 0.55, blue: 0.4, alpha: 0.35))] {
        let glow = CGGradient(colorsSpace: colorSpace, colors: [c, c.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
    }
    // Faint noise breaks up the banding a 256-colour GIF palette would otherwise show in the gradient.
    let smooth = CIImage(cgImage: ctx.makeImage()!)
    let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!
        .cropped(to: CGRect(origin: .zero, size: canvas))
        .applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.035),
            "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0),
        ])
        .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)])
    let mixed = noise.composited(over: smooth)
    return CIContext().createCGImage(mixed, from: CGRect(origin: .zero, size: canvas))!
}()

let blurredWallpaper: CGImage = {
    let input = CIImage(cgImage: wallpaper).clampedToExtent()
    let blurred = input.applyingGaussianBlur(sigma: 28).cropped(to: CGRect(origin: .zero, size: canvas))
    return CIContext().createCGImage(blurred, from: CGRect(origin: .zero, size: canvas))!
}()

func drawText(_ text: String, in ctx: CGContext, at y: CGFloat, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(white: 1, alpha: alpha),
    ]
    let string = NSAttributedString(string: text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(string)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    ctx.textPosition = CGPoint(x: (canvas.width - width) / 2, y: y)
    CTLineDraw(line, ctx)
}

/// Wallpaper + frosted HUD glass under the panel + the rendered panel + caption.
func compose(panel: CGImage?, caption: String, subcaption: String, showLogo: Bool = false) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(canvas.width), height: Int(canvas.height), bitsPerComponent: 8, bytesPerRow: 0,
                        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(wallpaper, in: CGRect(origin: .zero, size: canvas))
    drawText(caption, in: ctx, at: canvas.height - 58, size: 26, weight: .semibold, alpha: 0.96)
    drawText(subcaption, in: ctx, at: canvas.height - 88, size: 15, weight: .regular, alpha: 0.75)

    if showLogo, let logo {
        let side: CGFloat = 220
        ctx.draw(logo, in: CGRect(x: (canvas.width - side) / 2, y: (canvas.height - side) / 2 - 40, width: side, height: side))
    }
    guard let panel else { return ctx.makeImage()! }
    let scale: CGFloat = 0.82 / renderScale
    let size = CGSize(width: CGFloat(panel.width) * scale, height: CGFloat(panel.height) * scale)
    let rect = CGRect(x: (canvas.width - size.width) / 2, y: canvas.height - 112 - size.height, width: size.width, height: size.height)
    let shape = CGPath(roundedRect: rect, cornerWidth: Theme.cornerRadius * 0.82, cornerHeight: Theme.cornerRadius * 0.82, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: CGColor(gray: 0, alpha: 0.55))
    ctx.addPath(shape); ctx.setFillColor(CGColor(gray: 0.1, alpha: 1)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    ctx.draw(blurredWallpaper, in: CGRect(origin: .zero, size: canvas))
    ctx.setFillColor(CGColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 0.80))
    ctx.fill(rect)
    ctx.draw(panel, in: rect)
    ctx.restoreGState()
    return ctx.makeImage()!
}

// MARK: - Script

struct Frame { let image: CGImage; let seconds: Double }
var frames: [Frame] = []

@MainActor
func run() async {
    // Root search (Option+Space).
    let root = RootSearchModel()
    for (_, path) in appPaths { if let image = icon(path) { root.icons[path] = image } }
    let rootView = RootSearchView(model: root, onQueryChange: {}, onMove: { _ in }, onRecall: { _ in false }, onSubmit: {},
                                  onCancel: {}, onActivate: { _ in }, onSettings: {}, onKey: { _ in false })
    let rootRenderer = PanelRenderer(PanelChrome { rootView }, size: Theme.rootSize)
    let rootCaption = ("⌥ Space", "Launch apps and calculate")

    func rootFrame(_ query: String, _ items: [RootItem], copied: Bool = false, _ seconds: Double) async {
        root.query = query
        root.items = items
        root.selection = 0
        root.showsCopied = copied
        frames.append(Frame(image: compose(panel: await rootRenderer.capture(), caption: rootCaption.0, subcaption: rootCaption.1), seconds: seconds))
    }
    let suggestions = ["Safari", "Notes", "Calendar", "Mail", "Terminal", "Music", "Maps", "Photos"].map { RootItem.app(app($0)) }
    await rootFrame("", suggestions, 1.4)
    await rootFrame("c", ["Calendar", "Calculator", "Music", "Maps"].map { .app(app($0)) }, 0.12)
    await rootFrame("ca", ["Calendar", "Calculator"].map { .app(app($0)) }, 0.12)
    await rootFrame("cal", ["Calendar", "Calculator"].map { .app(app($0)) }, 1.0)
    let partials: [(String, String?)] = [("5", nil), ("5 ", nil), ("5 %", nil), ("5 % ", nil), ("5 % o", nil), ("5 % of", nil),
                                         ("5 % of ", nil), ("5 % of 5", "0.25"), ("5 % of 50", "2.5"), ("5 % of 500", "25"),
                                         ("5 % of 5000", "250")]
    for (index, (query, value)) in partials.enumerated() {
        let items: [RootItem] = value.map { [.calculation(CalculationResult(expression: query, value: $0))] } ?? []
        await rootFrame(query, items, index == partials.count - 1 ? 1.6 : 0.09)
    }
    await rootFrame("5 % of 5000", [.calculation(CalculationResult(expression: "5 % of 5000", value: "250"))], copied: true, 1.0)

    // Window search (Option+Tab).
    let search = WindowSearchModel()
    let searchView = WindowSearchView(model: search, onMove: { _ in }, onRecall: { _ in false }, onSubmit: {}, onCancel: {}, onActivate: { _ in })
    let searchRenderer = PanelRenderer(PanelChrome { searchView }, size: Theme.rootSize)
    search.all = allWindows
    func searchFrame(_ query: String, _ seconds: Double) async {
        search.query = query
        frames.append(Frame(image: compose(panel: await searchRenderer.capture(), caption: "⌥ Tab", subcaption: "Search every window, on every Desktop"), seconds: seconds))
    }
    await searchFrame("", 1.4)
    for (i, partial) in ["n", "no", "not", "note", "notes"].enumerated() { await searchFrame(partial, i == 4 ? 1.4 : 0.1) }
    for (i, partial) in ["s", "sa", "saf", "safa", "safar", "safari"].enumerated() { await searchFrame(partial, i == 5 ? 1.6 : 0.1) }

    // Switcher (Control+Tab).
    let switcher = SwitcherModel()
    switcher.appName = "Safari"
    switcher.appIcon = icon(appPaths["Safari"]!)
    switcher.windows = safariWindows
    let switcherRenderer = PanelRenderer(PanelChrome { SwitcherView(model: switcher) }, size: nil)
    for (highlight, seconds) in [(1, 1.0), (2, 0.7), (3, 0.7), (1, 1.2)] {
        switcher.highlighted = highlight
        frames.append(Frame(image: compose(panel: await switcherRenderer.capture(), caption: "⌃ Tab",
                                           subcaption: "Switch between windows of the current app · release ⌃ to jump"), seconds: seconds))
    }
    frames.append(Frame(image: compose(panel: nil, caption: "Beam", subcaption: "Native, fast, and free · macOS 15+", showLogo: true), seconds: 2.0))

    writeGIF()
    exit(0)
}

func writeGIF() {
    let url = URL(fileURLWithPath: outputPath)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for frame in frames {
        let props = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frame.seconds,
                                                     kCGImagePropertyGIFUnclampedDelayTime: frame.seconds]] as CFDictionary
        CGImageDestinationAddImage(destination, frame.image, props)
    }
    guard CGImageDestinationFinalize(destination) else { print("GIF write failed"); exit(1) }
    let total = frames.reduce(0) { $0 + $1.seconds }
    print("wrote \(outputPath): \(frames.count) frames, \(String(format: "%.1f", total)) s")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
DispatchQueue.main.async { Task { @MainActor in await run() } }
app.run()
