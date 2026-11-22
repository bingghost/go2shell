// Draws the Go2Shell app icon and packs it into Resources/AppIcon.icns.
// Run from the repository root:  swift Scripts/make-icon.swift   (or `make icon`)
//
// Design: no background plate. A silver-gray arrow that doubles as the shell prompt ">" plus a
// cursor "_" on a fully transparent canvas, in the spirit of the legacy Go2Shell toolbar icon.
// The mid gray is chosen to stay readable on both the light and the dark Finder toolbar.
// Also writes docs/images/icon-preview.png.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// All geometry is expressed on a 1024-point canvas and scaled to the output size.
let canvas: CGFloat = 1024

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func drawIcon(in context: CGContext, pixels: Int) {
    let scale = CGFloat(pixels) / canvas
    context.scaleBy(x: scale, y: scale)

    // Glyphs: thick round strokes so they survive at 16px. Authored around (512, 520) and
    // enlarged so the glyph spans the canvas width, leaving a 40pt transparent margin.
    var transform = CGAffineTransform(translationX: 512, y: 512)
        .scaledBy(x: 1.6, y: 1.6)
        .translatedBy(x: -512, y: -520)

    let strokes = CGMutablePath()
    // Arrow / prompt.
    strokes.move(to: CGPoint(x: 262, y: 530))
    strokes.addLine(to: CGPoint(x: 548, y: 530))
    strokes.move(to: CGPoint(x: 410, y: 668))
    strokes.addLine(to: CGPoint(x: 548, y: 530))
    strokes.addLine(to: CGPoint(x: 410, y: 392))
    // Cursor.
    strokes.move(to: CGPoint(x: 630, y: 372))
    strokes.addLine(to: CGPoint(x: 762, y: 372))

    let outline = strokes.copy(strokingWithWidth: 88, lineCap: .round, lineJoin: .round, miterLimit: 10)
    guard let glyph = outline.copy(using: &transform) else { return }
    let bounds = glyph.boundingBoxOfPath

    // Silver gradient, lighter at the top. Nothing is drawn outside the glyph (no plate, no
    // shadow), so everything around it stays transparent.
    context.saveGState()
    context.addPath(glyph)
    context.clip(using: .winding)
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0xA4A9B1), color(0x8A8F97), color(0x6F747C)] as CFArray,
        locations: [0, 0.5, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 512, y: bounds.maxY),
        end: CGPoint(x: 512, y: bounds.minY),
        options: []
    )
    context.restoreGState()
}

func renderPNG(pixels: Int, to url: URL) throws {
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    context.interpolationQuality = .high
    drawIcon(in: context, pixels: pixels)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let output = root.appendingPathComponent("Resources/AppIcon.icns")
let preview = root.appendingPathComponent("docs/images/icon-preview.png")

guard fileManager.fileExists(atPath: root.appendingPathComponent("Package.swift").path) else {
    FileHandle.standardError.write(Data("Run this from the repository root.\n".utf8))
    exit(1)
}

let iconset = fileManager.temporaryDirectory
    .appendingPathComponent("Go2Shell-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
    .appendingPathComponent("AppIcon.iconset", isDirectory: true)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconset.deletingLastPathComponent()) }

for points in [16, 32, 128, 256, 512] {
    try renderPNG(pixels: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try renderPNG(pixels: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", "--output", output.path, iconset.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed.\n".utf8))
    exit(1)
}

try fileManager.createDirectory(at: preview.deletingLastPathComponent(), withIntermediateDirectories: true)
try renderPNG(pixels: 512, to: preview)

print("Wrote \(output.path)")
print("Wrote \(preview.path)")
