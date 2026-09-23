#!/usr/bin/env swift
import AppKit
import Foundation

/// Recolors NewFile's orange I-beam to Nufi's teal. Layout stays identical.

let names = [
    "icon_16x16", "icon_16x16@2x",
    "icon_32x32", "icon_32x32@2x",
    "icon_128x128", "icon_128x128@2x",
    "icon_256x256", "icon_256x256@2x",
    "icon_512x512", "icon_512x512@2x",
]

let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset")

let tealR: UInt8 = 22
let tealG: UInt8 = 163
let tealB: UInt8 = 148

func isOrangeIBeam(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8) -> Bool {
    guard a > 50 else { return false }
    return Int(r) > 178 && Int(r) > Int(g) + 38 && Int(r) > Int(b) + 64 && g < 140
}

for name in names {
    let url = dir.appendingPathComponent("\(name).png")
    guard let image = NSImage(contentsOf: url),
          let tiff = image.tiffRepresentation,
          let src = NSBitmapImageRep(data: tiff),
          let dest = src.converting(to: .deviceRGB, renderingIntent: .default) ?? NSBitmapImageRep(data: tiff)
    else {
        fputs("failed to read \(name)\n", stderr)
        exit(1)
    }

    let w = dest.pixelsWide
    let h = dest.pixelsHigh
    let bpp = dest.bitsPerPixel / 8
    guard bpp >= 4, let data = dest.bitmapData else {
        fputs("no bitmap data for \(name)\n", stderr)
        exit(1)
    }
    let row = dest.bytesPerRow
    for y in 0..<h {
        for x in 0..<w {
            let i = y * row + x * bpp
            let r = data[i], g = data[i + 1], b = data[i + 2], a = data[i + 3]
            if isOrangeIBeam(r, g, b, a) {
                data[i] = tealR
                data[i + 1] = tealG
                data[i + 2] = tealB
            }
        }
    }
    guard let png = dest.representation(using: .png, properties: [:]) else {
        fputs("failed to encode \(name)\n", stderr)
        exit(1)
    }
    try png.write(to: url)
    print("recolored \(name)")
}
