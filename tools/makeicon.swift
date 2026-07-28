// Run via: swift tools/makeicon.swift <output.icns>
//
// Draws the m_tools app icon in code (CoreGraphics/AppKit) and writes a real
// multi-resolution .icns directly — no image assets, and no sips/iconutil shell-out
// (those need a system temp dir a sandboxed build might not have).
//
// The artwork is direction "1b — Brand solid" from the branding directions doc: a brand
// purple squircle, white braces, an `m` monogram, and an amber cursor block. Coordinates
// below are transcribed 1:1 from that 1024×1024 SVG so the app icon and the website mark
// stay in sync — if one changes, change the other to match.

import Foundation
import CoreGraphics
import AppKit

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift makeicon.swift <output.icns>")
    exit(1)
}
let outputPath = CommandLine.arguments[1]

// MARK: - Palette (mirrors Sources/Theme.swift)

let brandPurple = NSColor(srgbRed: 0x3B / 255.0, green: 0x2A / 255.0, blue: 0x78 / 255.0, alpha: 1)
let brandAmber = NSColor(srgbRed: 0xFF / 255.0, green: 0xB0 / 255.0, blue: 0x20 / 255.0, alpha: 1)

// MARK: - Geometry, in the design's 1024×1024 space

let canvas: CGFloat = 1024
let cornerRadius: CGFloat = 224

/// The SVG places things in a y-down coordinate space; AppKit draws y-up. Converting each
/// coordinate as it's used keeps the text upright — flipping the whole context instead
/// would render every glyph upside down.
func flip(_ svgY: CGFloat) -> CGFloat { canvas - svgY }

/// Manrope is the brand typeface but isn't a system font, so it's only present if it's
/// been installed (see README). Falling back to the heaviest system face keeps the build
/// working everywhere; the icon just renders in SF instead of Manrope.
func brandFont(size: CGFloat) -> NSFont {
    NSFont(name: "Manrope-ExtraBold", size: size)
        ?? NSFont(name: "Manrope", size: size)
        ?? NSFont.systemFont(ofSize: size, weight: .heavy)
}

/// Draws `text` centered on (`centerX`, `centerY`) — the SVG's
/// `text-anchor="middle" dominant-baseline="central"`.
func drawCentered(_ text: String, centerX: CGFloat, centerY: CGFloat, size: CGFloat, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: brandFont(size: size),
        .foregroundColor: color,
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let bounds = attributed.size()
    attributed.draw(at: NSPoint(x: centerX - bounds.width / 2, y: centerY - bounds.height / 2))
}

func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
}

/// The whole icon, drawn at 1024×1024. Callers scale the context to the size they need.
func drawIcon() {
    // Squircle field.
    brandPurple.setFill()
    roundedRect(x: 0, y: 0, width: canvas, height: canvas, radius: cornerRadius).fill()

    // Braces, slightly translucent so they sit *in* the purple rather than on top of it.
    let braceWhite = NSColor.white.withAlphaComponent(0.92)
    drawCentered("{", centerX: 196, centerY: flip(512), size: 640, color: braceWhite)
    drawCentered("}", centerX: 828, centerY: flip(512), size: 640, color: braceWhite)

    // `m` monogram.
    drawCentered("m", centerX: 470, centerY: flip(482), size: 360, color: .white)

    // Amber cursor block beneath the monogram. The SVG's y is the rect's top edge while
    // AppKit's is the bottom edge, hence subtracting the height before flipping.
    brandAmber.setFill()
    roundedRect(x: 378, y: flip(668 + 66), width: 184, height: 66, radius: 20).fill()
}

// MARK: - Rasterizing

func renderPNG(pixelSize: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(pixelSize) / canvas
    context.cgContext.scaleBy(x: scale, y: scale)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

// MARK: - ICNS container
//
// An .icns is a deliberately simple container: the ASCII magic "icns", a big-endian total
// byte length, then a flat run of chunks — each a 4-byte OSType, a big-endian length
// (counting its own 8-byte header), and the payload. Modern OSTypes take a raw PNG as
// that payload, which is what makes assembling this without iconutil practical.

func bigEndianBytes(_ value: UInt32) -> [UInt8] {
    [UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
}

/// OSType → pixel dimensions. Retina variants are listed at their real pixel size (a 16pt
/// @2x icon is a 32px image), which is why some sizes appear twice under two types.
let iconTypes: [(type: String, pixels: Int)] = [
    ("icp4", 16),    // 16×16
    ("icp5", 32),    // 32×32
    ("ic11", 32),    // 16×16@2x
    ("ic12", 64),    // 32×32@2x
    ("ic07", 128),   // 128×128
    ("ic13", 256),   // 128×128@2x
    ("ic08", 256),   // 256×256
    ("ic14", 512),   // 256×256@2x
    ("ic09", 512),   // 512×512
    ("ic10", 1024),  // 512×512@2x
]

var chunks = Data()
// Rendering is the slow part, so each distinct pixel size is rasterized once and shared
// by every OSType that needs it.
var pngCache: [Int: Data] = [:]

for entry in iconTypes {
    let png: Data
    if let cached = pngCache[entry.pixels] {
        png = cached
    } else {
        guard let rendered = renderPNG(pixelSize: entry.pixels) else {
            print("makeicon.swift: failed to render \(entry.pixels)px")
            exit(1)
        }
        pngCache[entry.pixels] = rendered
        png = rendered
    }

    chunks.append(contentsOf: Array(entry.type.utf8))
    chunks.append(contentsOf: bigEndianBytes(UInt32(png.count + 8)))
    chunks.append(png)
}

var icns = Data()
icns.append(contentsOf: Array("icns".utf8))
icns.append(contentsOf: bigEndianBytes(UInt32(chunks.count + 8)))
icns.append(chunks)

do {
    try icns.write(to: URL(fileURLWithPath: outputPath))
    print("makeicon.swift: wrote \(iconTypes.count) representations (\(icns.count) bytes) → \(outputPath)")
} catch {
    print("makeicon.swift: couldn't write \(outputPath): \(error.localizedDescription)")
    exit(1)
}
