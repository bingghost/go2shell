// Draws the Go2Shell app icon and packs it into Resources/AppIcon.icns.
// Run from the repository root:  swift Scripts/make-icon.swift   (or `make icon`)
//
// Design: a wide rounded rectangle with an arrow that doubles as the shell prompt ">" and a
// cursor "_" — "go into this folder, in a terminal". Also writes docs/images/icon-preview.png.

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

    // Body: a wide rounded rectangle that fills almost the whole canvas width. The icon is
    // mostly seen in the Finder toolbar, where the standard 824pt square (with its 100pt
    // margins) looks small next to other toolbar items.
    let body = CGRect(x: 24, y: 142, width: 976, height: 740)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 170, cornerHeight: 170, transform: nil)

    // Soft drop shadow under the body.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: color(0x000000, alpha: 0.30))
    context.addPath(bodyPath)
    context.setFillColor(color(0x3A3FD6))
    context.fillPath()
    context.restoreGState()

    // Body gradient, lighter at the top.
    context.saveGState()
    context.addPath(bodyPath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0x5C93FF), color(0x3438C8)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 512, y: body.maxY),
        end: CGPoint(x: 512, y: body.minY),
        options: []
    )
    context.restoreGState()

    // Glyphs: thick round strokes so they survive at 16px. Drawn around (512, 520) and
    // enlarged to use the wider body.
    context.translateBy(x: 512, y: 512)
    context.scaleBy(x: 1.2, y: 1.2)
    context.translateBy(x: -512, y: -520)
    context.setLineWidth(88)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // Arrow / prompt.
    context.setStrokeColor(color(0xFFFFFF))
    context.move(to: CGPoint(x: 262, y: 530))
    context.addLine(to: CGPoint(x: 548, y: 530))
    context.move(to: CGPoint(x: 410, y: 668))
    context.addLine(to: CGPoint(x: 548, y: 530))
    context.addLine(to: CGPoint(x: 410, y: 392))
    context.strokePath()

    // Cursor.
    context.setStrokeColor(color(0xBFE3FF))
    context.move(to: CGPoint(x: 630, y: 372))
    context.addLine(to: CGPoint(x: 762, y: 372))
    context.strokePath()
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
