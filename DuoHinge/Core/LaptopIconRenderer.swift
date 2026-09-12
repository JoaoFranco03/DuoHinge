import AppKit

enum LaptopIconRenderer {
    static func render(angle: Double, isEnabled: Bool = true, hasPermission: Bool = true) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            context.setLineCap(.round)
            context.setLineJoin(.round)

            let color = NSColor.black
            color.setStroke()
            color.setFill()

            // Hinge position and laptop dimensions
            let hinge = CGPoint(x: 6.5, y: 3.5)
            let length: CGFloat = 9.0
            let baseEnd = CGPoint(x: hinge.x + length, y: hinge.y)

            // Draw Base (Keyboard Deck)
            let basePath = NSBezierPath()
            basePath.lineWidth = 1.6
            basePath.lineCapStyle = .round
            basePath.move(to: hinge)
            basePath.line(to: baseEnd)
            basePath.stroke()

            // Clamp angle between 0° and 140°
            let safeAngle = (angle.isFinite ? min(max(angle, 0), 140) : 90.0)
            let rad = safeAngle * .pi / 180.0
            let lidEnd = CGPoint(
                x: hinge.x + length * CGFloat(cos(rad)),
                y: hinge.y + length * CGFloat(sin(rad))
            )

            // Draw Display Lid
            let lidPath = NSBezierPath()
            lidPath.lineWidth = 1.6
            lidPath.lineCapStyle = .round
            lidPath.move(to: hinge)
            lidPath.line(to: lidEnd)
            lidPath.stroke()

            // Draw Hinge Pivot
            let pivotRect = NSRect(x: hinge.x - 0.8, y: hinge.y - 0.8, width: 1.6, height: 1.6)
            let pivotPath = NSBezierPath(ovalIn: pivotRect)
            pivotPath.fill()

            if !hasPermission {
                // Warning triangle badge with exclamation cutout in top right
                let triangle = NSBezierPath()
                triangle.lineWidth = 1.0
                triangle.lineCapStyle = .round
                triangle.lineJoinStyle = .round
                triangle.move(to: CGPoint(x: 14.0, y: 15.5))
                triangle.line(to: CGPoint(x: 10.5, y: 9.0))
                triangle.line(to: CGPoint(x: 17.5, y: 9.0))
                triangle.close()
                NSColor.black.setFill()
                NSColor.black.setStroke()
                triangle.fill()
                triangle.stroke()

                // Cut out exclamation mark
                context.saveGState()
                context.setBlendMode(.clear)

                let stem = NSBezierPath()
                stem.lineWidth = 1.0
                stem.lineCapStyle = .round
                stem.move(to: CGPoint(x: 14.0, y: 13.4))
                stem.line(to: CGPoint(x: 14.0, y: 11.4))
                stem.stroke()

                let dot = NSRect(x: 13.5, y: 9.6, width: 1.0, height: 1.0)
                NSBezierPath(ovalIn: dot).fill()

                context.restoreGState()
            } else if !isEnabled {
                // Disabled slash
                let slashPath = NSBezierPath()
                slashPath.lineWidth = 1.2
                slashPath.lineCapStyle = .round
                slashPath.move(to: CGPoint(x: 3.0, y: 15.0))
                slashPath.line(to: CGPoint(x: 15.0, y: 3.0))
                slashPath.stroke()
            }

            return true
        }
        image.isTemplate = true
        return image
    }
}
