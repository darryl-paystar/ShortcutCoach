// Renders Resources/AppIcon.icns: a keycap with ⌘ on an indigo squircle. Run: swift scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    let ctx = NSGraphicsContext.current!.cgContext

    // Background squircle (Apple icon grid: 824pt body, 100pt inset).
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let bg = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 24 * s, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSColor.black.setFill(); bg.fill()
    ctx.restoreGState()
    bg.addClip()
    NSGradient(colors: [NSColor(calibratedRed: 0.36, green: 0.33, blue: 0.96, alpha: 1),
                        NSColor(calibratedRed: 0.62, green: 0.30, blue: 0.93, alpha: 1)])!.draw(in: body, angle: -60)

    // Keycap
    let cap = NSRect(x: 262 * s, y: 250 * s, width: 500 * s, height: 500 * s)
    let base = NSBezierPath(roundedRect: cap.offsetBy(dx: 0, dy: -26 * s), xRadius: 96 * s, yRadius: 96 * s)
    NSColor(calibratedWhite: 0.80, alpha: 1).setFill(); base.fill()
    let top = NSBezierPath(roundedRect: cap, xRadius: 96 * s, yRadius: 96 * s)
    NSGradient(colors: [NSColor.white, NSColor(calibratedWhite: 0.93, alpha: 1)])!.draw(in: top, angle: -90)

    // ⌘ glyph
    let config = NSImage.SymbolConfiguration(pointSize: 300 * s, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "command", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let tinted = NSImage(size: sym.size, flipped: false) { r in
            sym.draw(in: r)
            NSColor(calibratedRed: 0.40, green: 0.31, blue: 0.93, alpha: 1).set()
            r.fill(using: .sourceAtop)
            return true
        }
        let size = tinted.size
        tinted.draw(in: NSRect(x: cap.midX - size.width / 2, y: cap.midY - size.height / 2 + 4 * s, width: size.width, height: size.height))
    }
    // Sparkle: "you're learning"
    if let spark = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 150 * s, weight: .bold)) {
        let t = NSImage(size: spark.size, flipped: false) { r in
            spark.draw(in: r); NSColor(calibratedRed: 1, green: 0.85, blue: 0.3, alpha: 1).set(); r.fill(using: .sourceAtop); return true
        }
        t.draw(in: NSRect(x: 690 * s, y: 680 * s, width: t.size.width, height: t.size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: out)
try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: out.appendingPathComponent("icon_\(name).png"))
}
