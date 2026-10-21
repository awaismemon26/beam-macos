import AppKit
import CoreGraphics

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.displayP3)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, a])! }
func grad(_ stops: [(CGColor, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: stops.map(\.0) as CFArray, locations: stops.map(\.1))!
}

// macOS icon grid: 824pt squircle centred in 1024, continuous corners.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185).cgPath

// Drop shadow under the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: c(0, 0, 0, 0.35))
ctx.addPath(squircle); ctx.setFillColor(c(0.05, 0.06, 0.15)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle); ctx.clip()
// Night-sky gradient.
ctx.drawLinearGradient(grad([(c(0.04, 0.05, 0.16), 0), (c(0.13, 0.08, 0.33), 0.55), (c(0.24, 0.10, 0.45), 1)]),
                       start: CGPoint(x: 150, y: 100), end: CGPoint(x: 880, y: 924), options: [])

// Source of the beam: lower-left.
let source = CGPoint(x: 275, y: 285)
// Target: the front window card, upper-right.
let cards: [(CGRect, CGFloat)] = [
    (CGRect(x: 520, y: 600, width: 300, height: 210), 0.18),
    (CGRect(x: 480, y: 545, width: 300, height: 210), 0.30),
    (CGRect(x: 440, y: 490, width: 300, height: 210), 1.0),
]
let front = cards[2].0

// The beam: a widening wedge from the source onto the front card.
ctx.saveGState()
let wedge = CGMutablePath()
wedge.move(to: source)
wedge.addLine(to: CGPoint(x: front.minX + 10, y: front.maxY - 8))
wedge.addLine(to: CGPoint(x: front.maxX - 20, y: front.minY + 6))
wedge.closeSubpath()
ctx.addPath(wedge); ctx.clip()
ctx.drawLinearGradient(grad([(c(0.55, 0.95, 1.0, 0.95), 0), (c(0.45, 0.75, 1.0, 0.55), 0.55), (c(0.75, 0.55, 1.0, 0.10), 1)]),
                       start: source, end: CGPoint(x: front.midX, y: front.midY), options: [])
ctx.restoreGState()

// Window cards (back to front), glassy.
for (rect, alpha) in cards {
    let path = NSBezierPath(roundedRect: rect, xRadius: 34, yRadius: 34).cgPath
    ctx.saveGState()
    if alpha == 1 {
        ctx.setShadow(offset: .zero, blur: 60, color: c(0.45, 0.85, 1.0, 0.85)) // lit by the beam
    }
    ctx.addPath(path)
    ctx.setFillColor(alpha == 1 ? c(0.93, 0.97, 1.0) : c(0.75, 0.70, 1.0, alpha))
    ctx.fillPath()
    ctx.restoreGState()
    if alpha == 1 {
        // Title bar dots and two content lines on the front card.
        let dotY = rect.maxY - 38
        for (i, col) in [c(1.0, 0.37, 0.34), c(1.0, 0.75, 0.2), c(0.2, 0.8, 0.35)].enumerated() {
            ctx.setFillColor(col)
            ctx.fillEllipse(in: CGRect(x: rect.minX + 30 + CGFloat(i) * 32, y: dotY - 10, width: 20, height: 20))
        }
        ctx.setFillColor(c(0.36, 0.40, 0.62, 0.35))
        for (i, w) in [CGFloat(200), 140].enumerated() {
            let line = CGRect(x: rect.minX + 30, y: rect.maxY - 95 - CGFloat(i) * 42, width: w, height: 18)
            ctx.addPath(NSBezierPath(roundedRect: line, xRadius: 9, yRadius: 9).cgPath); ctx.fillPath()
        }
    }
}

// Glowing source: bright core + radial bloom + four-point sparkle.
ctx.drawRadialGradient(grad([(c(0.8, 1.0, 1.0, 0.9), 0), (c(0.4, 0.8, 1.0, 0.35), 0.35), (c(0.4, 0.6, 1.0, 0), 1)]),
                       startCenter: source, startRadius: 0, endCenter: source, endRadius: 170, options: [])
let star = CGMutablePath()
let (r1, r2): (CGFloat, CGFloat) = (82, 14)
for i in 0..<8 {
    let angle = CGFloat(i) * .pi / 4 + .pi / 2
    let r = i % 2 == 0 ? r1 : r2
    let p = CGPoint(x: source.x + cos(angle) * r, y: source.y + sin(angle) * r)
    i == 0 ? star.move(to: p) : star.addLine(to: p)
}
star.closeSubpath()
ctx.addPath(star); ctx.setFillColor(c(1, 1, 1)); ctx.fillPath()
ctx.setFillColor(c(1, 1, 1)); ctx.fillEllipse(in: CGRect(x: source.x - 14, y: source.y - 14, width: 28, height: 28))

// Subtle top highlight on the tile.
ctx.drawLinearGradient(grad([(c(1, 1, 1, 0.10), 0), (c(1, 1, 1, 0), 0.35)]),
                       start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
