#!/usr/bin/env swift
import AppKit

/// Renders Nufi's app icon on Apple's macOS grid: a 824 pt rounded square
/// centred on a 1024 canvas with transparent margins, so the Dock shows it
/// at the same size as every other app. Writes the appiconset PNGs and a
/// 1024 master into App/Assets.xcassets/Nufi.appiconset.

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let out = root.appendingPathComponent("App/Assets.xcassets/Nufi.appiconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)


func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

func draw(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let s = size / 1024
    let ctx = NSGraphicsContext.current!
    ctx.imageInterpolation = .high
    // Top-down 1024 coordinates like the SVG layers; `y` flips for AppKit.
    func y(_ v: CGFloat) -> CGFloat { (1024 - v) * s }
    func x(_ v: CGFloat) -> CGFloat { v * s }
    func pt(_ px: CGFloat, _ py: CGFloat) -> NSPoint { NSPoint(x: x(px), y: y(py)) }

    // Plate: 940 pt with a vertical gradient and a glass sheen on top.
    let plateRect = NSRect(x: x(42), y: y(982), width: 940 * s, height: 940 * s)
    let plate = NSBezierPath(roundedRect: plateRect, xRadius: 210 * s, yRadius: 210 * s)
    NSGradient(starting: rgb(0x2C2825), ending: rgb(0x131110))!.draw(in: plate, angle: -90)
    ctx.saveGraphicsState()
    plate.addClip()
    NSGradient(colorsAndLocations: (rgb(0xFFFFFF, 0.14), 0), (rgb(0xFFFFFF, 0.0), 0.55))!
        .draw(in: NSRect(x: x(42), y: y(982), width: 940 * s, height: 940 * s), angle: -90)
    // Inner rim highlight along the top edge.
    let rim = NSBezierPath(roundedRect: plateRect.insetBy(dx: 3 * s, dy: 3 * s), xRadius: 207 * s, yRadius: 207 * s)
    rim.lineWidth = 4 * s
    rgb(0xFFFFFF, 0.18).setStroke()
    rim.stroke()
    ctx.restoreGraphicsState()

    // Paper sheet with a folded corner, casting a soft shadow.
    let sheet = NSBezierPath()
    sheet.move(to: pt(296, 168))
    sheet.line(to: pt(632, 168))
    sheet.line(to: pt(762, 298))
    sheet.line(to: pt(762, 822))
    sheet.curve(to: pt(728, 856), controlPoint1: pt(762, 841), controlPoint2: pt(747, 856))
    sheet.line(to: pt(296, 856))
    sheet.curve(to: pt(262, 822), controlPoint1: pt(277, 856), controlPoint2: pt(262, 841))
    sheet.line(to: pt(262, 202))
    sheet.curve(to: pt(296, 168), controlPoint1: pt(262, 183), controlPoint2: pt(277, 168))
    sheet.close()
    ctx.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = rgb(0x000000, 0.55)
    shadow.shadowBlurRadius = 26 * s
    shadow.shadowOffset = NSSize(width: 0, height: -12 * s)
    shadow.set()
    rgb(0xF4EFE5).setFill()
    sheet.fill()
    ctx.restoreGraphicsState()
    ctx.saveGraphicsState()
    sheet.addClip()
    NSGradient(starting: rgb(0xFFFDF8), ending: rgb(0xE9E3D7))!.draw(in: sheet.bounds, angle: -90)
    // Faint text lines: it is a text file.
    rgb(0xC6BFB0).setFill()
    for (i, w) in [300, 340, 240, 320, 200].enumerated() {
        let ly = 372 + CGFloat(i) * 76
        NSBezierPath(roundedRect: NSRect(x: x(336), y: y(ly + 22), width: CGFloat(w) * s, height: 22 * s),
                     xRadius: 11 * s, yRadius: 11 * s).fill()
    }
    ctx.restoreGraphicsState()
    // Fold: a darker triangle turned over the corner, with its own shadow.
    let fold = NSBezierPath()
    fold.move(to: pt(632, 168))
    fold.line(to: pt(632, 268))
    fold.curve(to: pt(662, 298), controlPoint1: pt(632, 285), controlPoint2: pt(645, 298))
    fold.line(to: pt(762, 298))
    fold.close()
    ctx.saveGraphicsState()
    let foldShadow = NSShadow()
    foldShadow.shadowColor = rgb(0x000000, 0.35)
    foldShadow.shadowBlurRadius = 10 * s
    foldShadow.shadowOffset = NSSize(width: -4 * s, height: -6 * s)
    foldShadow.set()
    rgb(0xD8D1C3).setFill()
    fold.fill()
    ctx.restoreGraphicsState()
    ctx.saveGraphicsState()
    fold.addClip()
    NSGradient(starting: rgb(0xEDE7DB), ending: rgb(0xCBC3B3))!.draw(in: fold.bounds, angle: -135)
    ctx.restoreGraphicsState()

    // Solid plus badge at the bottom-left corner with a soft shadow.
    let c = pt(292, 796)
    let r: CGFloat = 168 * s
    let badge = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    ctx.saveGraphicsState()
    let badgeShadow = NSShadow()
    badgeShadow.shadowColor = rgb(0x000000, 0.45)
    badgeShadow.shadowBlurRadius = 20 * s
    badgeShadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    badgeShadow.set()
    rgb(0x16A394).setFill()
    badge.fill()
    ctx.restoreGraphicsState()
    ctx.saveGraphicsState()
    badge.addClip()
    NSGradient(colorsAndLocations: (rgb(0x33CBB8), 0), (rgb(0x16A394), 0.55), (rgb(0x0C7A6E), 1))!
        .draw(in: badge, relativeCenterPosition: NSPoint(x: -0.3, y: 0.45))
    let gloss = NSBezierPath(ovalIn: NSRect(x: c.x - r * 0.82, y: c.y + r * 0.05, width: r * 1.64, height: r * 0.9))
    NSGradient(starting: rgb(0xFFFFFF, 0.2), ending: rgb(0xFFFFFF, 0.0))!.draw(in: gloss, angle: -90)
    ctx.restoreGraphicsState()
    let bar: CGFloat = 46 * s, len: CGFloat = 196 * s
    ctx.saveGraphicsState()
    let plusShadow = NSShadow()
    plusShadow.shadowColor = rgb(0x000000, 0.3)
    plusShadow.shadowBlurRadius = 4 * s
    plusShadow.shadowOffset = NSSize(width: 0, height: -3 * s)
    plusShadow.set()
    rgb(0xFFFFFF).setFill()
    NSBezierPath(roundedRect: NSRect(x: c.x - len / 2, y: c.y - bar / 2, width: len, height: bar),
                 xRadius: bar / 2, yRadius: bar / 2).fill()
    NSBezierPath(roundedRect: NSRect(x: c.x - bar / 2, y: c.y - len / 2, width: bar, height: len),
                 xRadius: bar / 2, yRadius: bar / 2).fill()
    ctx.restoreGraphicsState()

    image.unlockFocus()
    return image
}

func write(_ image: NSImage, pixels: Int, name: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(size: CGFloat(pixels)).draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: out.appendingPathComponent(name))
    print("wrote \(name)")
}

let sizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for (pt, scale) in sizes {
    write(draw(size: 1024), pixels: pt * scale, name: "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png")
}
