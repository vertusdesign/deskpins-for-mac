#!/usr/bin/env swift
// Renders Resources/AppIcon.icns from the same drawing the pin marker uses, so the icon in
// the Dock, in Finder and in System Settings is the badge users click on their windows.
//
//     swift Scripts/make-icon.swift <output.icns>
//
// Needs no image assets: the artwork is a gradient disc plus the `pin.fill` SF Symbol.

import AppKit
import Foundation

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.icns>\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: arguments[1])

let gradient = NSGradient(
    starting: NSColor(srgbRed: 0.64, green: 0.86, blue: 0.38, alpha: 1),
    ending:   NSColor(srgbRed: 0.36, green: 0.68, blue: 0.20, alpha: 1))!

/// Draws the badge into a square bitmap of `size` points at 1× scale.
func renderIcon(size: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: size, pixelsHigh: size,
                                     bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let canvas = CGFloat(size)
    // macOS icons leave a margin around the artwork so they line up with system icons.
    let margin = canvas * 0.09
    let disc = NSRect(x: margin, y: margin,
                      width: canvas - margin * 2, height: canvas - margin * 2)

    // Drop shadow, same idea as the marker's but scaled to the icon.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = canvas * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -canvas * 0.015)
    shadow.set()

    let circle = NSBezierPath(ovalIn: disc)
    gradient.draw(in: circle, angle: -90)

    NSShadow().set()   // clear the shadow before the rim and the glyph

    NSColor.white.withAlphaComponent(0.55).setStroke()
    circle.lineWidth = max(1, canvas * 0.012)
    circle.stroke()

    let glyphSize = canvas * 0.36
    let config = NSImage.SymbolConfiguration(pointSize: glyphSize, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let pin = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let box = NSRect(x: (canvas - pin.size.width) / 2,
                         y: (canvas - pin.size.height) / 2,
                         width: pin.size.width, height: pin.size.height)
        pin.draw(in: box)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

// One PNG per size macOS asks for, named the way `iconutil` expects.
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16",      16), ("icon_16x16@2x",     32),
    ("icon_32x32",      32), ("icon_32x32@2x",     64),
    ("icon_128x128",   128), ("icon_128x128@2x",  256),
    ("icon_256x256",   256), ("icon_256x256@2x",  512),
    ("icon_512x512",   512), ("icon_512x512@2x", 1024),
]

let workDir = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("DeskPinsIcon-\(UUID().uuidString)")
let iconset = workDir.appendingPathComponent("AppIcon.iconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for variant in variants {
    guard let png = renderIcon(size: variant.pixels) else {
        FileHandle.standardError.write(Data("failed to render \(variant.name)\n".utf8))
        exit(1)
    }
    try! png.write(to: iconset.appendingPathComponent("\(variant.name).png"))
}

let convert = Process()
convert.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
convert.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try! convert.run()
convert.waitUntilExit()
try? FileManager.default.removeItem(at: workDir)

guard convert.terminationStatus == 0 else { exit(convert.terminationStatus) }
print("Icon written to \(output.path)")
