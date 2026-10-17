import AppKit
import CoreGraphics

func renderIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // 1. Background gradient squircle
    let rect = CGRect(x: s * 0.08, y: s * 0.08, width: s * 0.84, height: s * 0.84)
    let cornerRadius = s * 0.22
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // Deep midnight sapphire gradient
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.24, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.12, alpha: 1.0).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
    ctx.restoreGState()

    // 2. Translucent outer border
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setStrokeColor(NSColor(calibratedRed: 0.3, green: 0.5, blue: 0.9, alpha: 0.35).cgColor)
    ctx.setLineWidth(s * 0.02)
    ctx.strokePath()
    ctx.restoreGState()

    // 3. Draw clipboard board
    let boardRect = CGRect(x: s * 0.26, y: s * 0.20, width: s * 0.48, height: s * 0.58)
    let boardPath = CGPath(roundedRect: boardRect, cornerWidth: s * 0.05, cornerHeight: s * 0.05, transform: nil)

    ctx.saveGState()
    ctx.addPath(boardPath)
    ctx.setFillColor(NSColor(calibratedRed: 0.15, green: 0.20, blue: 0.36, alpha: 0.85).cgColor)
    ctx.fillPath()

    ctx.addPath(boardPath)
    ctx.setStrokeColor(NSColor(calibratedRed: 0.4, green: 0.65, blue: 1.0, alpha: 0.5).cgColor)
    ctx.setLineWidth(s * 0.015)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Draw clip top
    let clipRect = CGRect(x: s * 0.38, y: s * 0.72, width: s * 0.24, height: s * 0.10)
    let clipPath = CGPath(roundedRect: clipRect, cornerWidth: s * 0.03, cornerHeight: s * 0.03, transform: nil)
    ctx.saveGState()
    ctx.addPath(clipPath)
    ctx.setFillColor(NSColor(calibratedRed: 0.7, green: 0.75, blue: 0.9, alpha: 0.95).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // 5. Draw inner privacy shield & keyhole
    let shieldCenter = CGPoint(x: s * 0.5, y: s * 0.46)
    let shieldSize = s * 0.24
    let shieldRect = CGRect(x: shieldCenter.x - shieldSize/2, y: shieldCenter.y - shieldSize/2, width: shieldSize, height: shieldSize)

    ctx.saveGState()
    let shieldPath = CGMutablePath()
    shieldPath.move(to: CGPoint(x: shieldRect.midX, y: shieldRect.maxY))
    shieldPath.addLine(to: CGPoint(x: shieldRect.maxX, y: shieldRect.midY + shieldSize * 0.2))
    shieldPath.addLine(to: CGPoint(x: shieldRect.maxX, y: shieldRect.midY))
    shieldPath.addQuadCurve(to: CGPoint(x: shieldRect.midX, y: shieldRect.minY), control: CGPoint(x: shieldRect.maxX, y: shieldRect.minY + shieldSize * 0.2))
    shieldPath.addQuadCurve(to: CGPoint(x: shieldRect.minX, y: shieldRect.midY), control: CGPoint(x: shieldRect.minX, y: shieldRect.minY + shieldSize * 0.2))
    shieldPath.addLine(to: CGPoint(x: shieldRect.minX, y: shieldRect.midY + shieldSize * 0.2))
    shieldPath.closeSubpath()

    ctx.addPath(shieldPath)
    ctx.setFillColor(NSColor(calibratedRed: 0.2, green: 0.6, blue: 1.0, alpha: 0.9).cgColor)
    ctx.fillPath()

    // Keyhole circle
    let keyCircle = CGRect(x: shieldCenter.x - s * 0.025, y: shieldCenter.y, width: s * 0.05, height: s * 0.05)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: keyCircle)

    // Keyhole stem
    let stemPath = CGMutablePath()
    stemPath.move(to: CGPoint(x: shieldCenter.x - s * 0.015, y: shieldCenter.y + s * 0.01))
    stemPath.addLine(to: CGPoint(x: shieldCenter.x + s * 0.015, y: shieldCenter.y + s * 0.01))
    stemPath.addLine(to: CGPoint(x: shieldCenter.x + s * 0.02, y: shieldCenter.y - s * 0.035))
    stemPath.addLine(to: CGPoint(x: shieldCenter.x - s * 0.02, y: shieldCenter.y - s * 0.035))
    stemPath.closeSubpath()
    ctx.addPath(stemPath)
    ctx.fillPath()

    ctx.restoreGState()

    image.unlockFocus()
    return image
}

let fm = FileManager.default
let iconsetDir = URL(fileURLWithPath: "AppIcon.iconset")
try? fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes {
    let img = renderIcon(size: size)
    if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
        let name = "icon_\(size)x\(size).png"
        try? png.write(to: iconsetDir.appendingPathComponent(name))
        if size <= 512 {
            let name2x = "icon_\(size)x\(size)@2x.png"
            let img2x = renderIcon(size: size * 2)
            if let tiff2x = img2x.tiffRepresentation, let rep2x = NSBitmapImageRep(data: tiff2x), let png2x = rep2x.representation(using: .png, properties: [:]) {
                try? png2x.write(to: iconsetDir.appendingPathComponent(name2x))
            }
        }
    }
}

print("AppIcon images generated in AppIcon.iconset")
