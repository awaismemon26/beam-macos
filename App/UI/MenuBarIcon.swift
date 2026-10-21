import AppKit

/// The menu-bar glyph: Beam's logo reduced to a template image (a star casting a beam onto a window).
/// Template images are tinted by macOS for light/dark menu bars.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()

            // Window outline, upper right.
            let window = NSBezierPath(roundedRect: NSRect(x: 7.5, y: 8.5, width: 9.5, height: 7), xRadius: 2, yRadius: 2)
            window.lineWidth = 1.4
            window.stroke()

            // Beam from the star to the window's lower-left corner.
            let beam = NSBezierPath()
            beam.move(to: NSPoint(x: 4, y: 4))
            beam.line(to: NSPoint(x: 7.5, y: 12.5))
            beam.line(to: NSPoint(x: 12, y: 8.5))
            beam.close()
            NSColor.black.withAlphaComponent(0.55).setFill()
            beam.fill()

            // Four-point star, lower left.
            let star = NSBezierPath()
            let center = NSPoint(x: 4, y: 4)
            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4 + .pi / 2
                let radius: CGFloat = i % 2 == 0 ? 4 : 0.9
                let point = NSPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                i == 0 ? star.move(to: point) : star.line(to: point)
            }
            star.close()
            NSColor.black.setFill()
            star.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Beam"
        return image
    }()
}
