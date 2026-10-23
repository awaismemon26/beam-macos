// Draws the DMG window background: drag-to-Applications arrow plus first-launch steps.
//   swift Tools/DMG/DrawBackground.swift <out-dir>     writes background.png and background@2x.png
// Icon positions (points, from the top-left) must match Tools/DMG/settings.py. Everything sits in the top 330 points:
// Finder's path and status bars, when a user has them on, cover the bottom of the window.
import AppKit

let W: CGFloat = 660, H: CGFloat = 440
let iconY: CGFloat = 125, beamX: CGFloat = 175, appsX: CGFloat = 485

func render(scale: CGFloat, to url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }
    // Flip so y runs from the top, like Finder's icon positions.
    let t = NSAffineTransform(); t.translateX(by: 0, yBy: H); t.scaleX(by: 1, yBy: -1); t.concat()

    // Light, slightly cool background: Finder draws icon labels dark on it in both appearances.
    NSGradient(starting: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.99, alpha: 1),
               ending: NSColor(srgbRed: 0.91, green: 0.92, blue: 0.96, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90)

    let ink = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.16, alpha: 1)
    let muted = NSColor(srgbRed: 0.36, green: 0.37, blue: 0.45, alpha: 1)
    let accent = NSColor(srgbRed: 0.48, green: 0.36, blue: 1.0, alpha: 1)  // the README's release-badge purple

    func text(_ s: String, _ rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor,
              align: NSTextAlignment = .center) {
        let p = NSMutableParagraphStyle(); p.alignment = align; p.lineSpacing = 2
        NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                   .foregroundColor: color, .paragraphStyle: p])
            .draw(with: rect, options: [.usesLineFragmentOrigin])
    }
    func flipped(_ draw: () -> Void) { // NSAttributedString draws upright only in an unflipped context
        NSGraphicsContext.current!.saveGraphicsState()
        let u = NSAffineTransform(); u.translateX(by: 0, yBy: H); u.scaleX(by: 1, yBy: -1); u.concat()
        draw()
        NSGraphicsContext.current!.restoreGraphicsState()
    }

    // Arrow from Beam to Applications.
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: beamX + 78, y: iconY)); arrow.line(to: NSPoint(x: appsX - 86, y: iconY))
    arrow.lineWidth = 4; arrow.lineCapStyle = .round
    accent.setStroke(); arrow.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: appsX - 98, y: iconY - 12)); head.line(to: NSPoint(x: appsX - 84, y: iconY))
    head.line(to: NSPoint(x: appsX - 98, y: iconY + 12))
    head.lineWidth = 4; head.lineCapStyle = .round; head.lineJoinStyle = .round; head.stroke()

    // First-launch card.
    let card = NSRect(x: 40, y: 220, width: W - 80, height: 104)
    NSColor.white.withAlphaComponent(0.85).setFill()
    NSBezierPath(roundedRect: card, xRadius: 14, yRadius: 14).fill()
    NSColor(srgbRed: 0.80, green: 0.81, blue: 0.88, alpha: 1).setStroke()
    let border = NSBezierPath(roundedRect: card.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
    border.lineWidth = 1; border.stroke()

    flipped {
        func r(_ x: CGFloat, _ yTop: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: x, y: H - yTop - h, width: w, height: h)
        }
        text("Drag Beam into Applications", r(0, 22, W, 24), size: 17, weight: .semibold, color: ink)
        text("Opening Beam the first time", r(card.minX + 24, card.minY + 14, card.width - 48, 20),
             size: 14, weight: .semibold, color: ink, align: .left)
        let steps = """
        1.  macOS says it can't verify Beam (it isn't notarized yet). Click Done.
        2.  Open System Settings ▸ Privacy & Security, scroll down and click Open Anyway.
        3.  Open Beam again and turn on Accessibility when it asks.
        """
        text(steps, r(card.minX + 24, card.minY + 38, card.width - 48, 62),
             size: 12.5, weight: .regular, color: muted, align: .left)
    }

    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: url)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
render(scale: 1, to: out.appendingPathComponent("background.png"))
render(scale: 2, to: out.appendingPathComponent("background@2x.png"))
