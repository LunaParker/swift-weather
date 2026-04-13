#!/usr/bin/env swift
// generate_icon.swift — Renders an SF Symbol app icon with a blue gradient background
// and populates the AppIcon.appiconset with all required sizes.

import AppKit
import Foundation

// MARK: - Configuration

let symbolName = "cloud.sun.fill"
let outputDir = "SwiftWeather/Assets.xcassets/AppIcon.appiconset"

// Deep blue gradient colors
let gradientTopColor = NSColor(calibratedRed: 0.10, green: 0.30, blue: 0.85, alpha: 1.0)
let gradientBottomColor = NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.35, alpha: 1.0)

// Rounded-rect corner radius as a fraction of canvas size (macOS icon style)
let cornerRadiusFraction: CGFloat = 0.185

// MARK: - Icon rendering

func renderIcon(pixelSize: Int, applyRoundedRect: Bool) -> NSBitmapImageRep {
    let size = CGFloat(pixelSize)
    let rep = NSBitmapImageRep(
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
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // Clear to transparent
    cg.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Clip to rounded rect if macOS-style
    if applyRoundedRect {
        let radius = size * cornerRadiusFraction
        let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                                xRadius: radius, yRadius: radius)
        path.addClip()
    }

    // Draw gradient background
    let gradient = NSGradient(starting: gradientTopColor, ending: gradientBottomColor)!
    gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: 270) // top -> bottom

    // Render SF Symbol
    let pointSize = size * 0.48
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {

        let symbolSize = symbolImage.size
        let x = (size - symbolSize.width) / 2.0
        let y = (size - symbolSize.height) / 2.0
        symbolImage.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height),
                         from: .zero, operation: .sourceOver, fraction: 1.0)
    } else {
        print("Warning: Could not load SF Symbol '\(symbolName)'")
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func savePNG(rep: NSBitmapImageRep, to path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: path)
    try! data.write(to: url)
    print("  Wrote \(url.lastPathComponent)")
}

// MARK: - Size definitions

struct IconEntry {
    let filename: String
    let pixelSize: Int
    let idiom: String
    let size: String
    let scale: String?
    let platform: String?
    let appearance: String? // nil, "dark", "tinted"
    let roundedRect: Bool
}

let entries: [IconEntry] = [
    // iOS universal (1024x1024) — light, dark, tinted
    .init(filename: "icon_ios_1024.png",         pixelSize: 1024, idiom: "universal", size: "1024x1024", scale: nil, platform: "ios", appearance: nil,       roundedRect: false),
    .init(filename: "icon_ios_1024_dark.png",    pixelSize: 1024, idiom: "universal", size: "1024x1024", scale: nil, platform: "ios", appearance: "dark",    roundedRect: false),
    .init(filename: "icon_ios_1024_tinted.png",  pixelSize: 1024, idiom: "universal", size: "1024x1024", scale: nil, platform: "ios", appearance: "tinted",  roundedRect: false),
    // macOS sizes (rounded rect applied)
    .init(filename: "icon_mac_16x16_1x.png",    pixelSize: 16,   idiom: "mac", size: "16x16",   scale: "1x", platform: nil, appearance: nil, roundedRect: true),
    .init(filename: "icon_mac_16x16_2x.png",    pixelSize: 32,   idiom: "mac", size: "16x16",   scale: "2x", platform: nil, appearance: nil, roundedRect: true),
    .init(filename: "icon_mac_32x32_1x.png",    pixelSize: 32,   idiom: "mac", size: "32x32",   scale: "1x", platform: nil, appearance: nil, roundedRect: true),
    .init(filename: "icon_mac_32x32_2x.png",    pixelSize: 64,   idiom: "mac", size: "32x32",   scale: "2x", platform: nil, appearance: nil, roundedRect: true),
    .init(filename: "icon_mac_128x128_1x.png",  pixelSize: 128,  idiom: "mac", size: "128x128", scale: "1x", platform: nil, appearance: nil, roundedRect: true),
    .init(filename: "icon_mac_128x128_2x.png",  pixelSize: 256,  idiom: "mac", size: "128x128", scale: "2x", platform: nil, appearance: nil, roundedRect: true),
    .init(filename: "icon_mac_256x256_1x.png",  pixelSize: 256,  idiom: "mac", size: "256x256", scale: "1x", platform: nil, appearance: nil, roundedRect: true),
    .init(filename: "icon_mac_256x256_2x.png",  pixelSize: 512,  idiom: "mac", size: "256x256", scale: "2x", platform: nil, appearance: nil, roundedRect: true),
    .init(filename: "icon_mac_512x512_1x.png",  pixelSize: 512,  idiom: "mac", size: "512x512", scale: "1x", platform: nil, appearance: nil, roundedRect: true),
    .init(filename: "icon_mac_512x512_2x.png",  pixelSize: 1024, idiom: "mac", size: "512x512", scale: "2x", platform: nil, appearance: nil, roundedRect: true),
]

// MARK: - Generate icons

print("Generating app icons with SF Symbol '\(symbolName)'...")

// Cache rendered images by (pixelSize, roundedRect) to avoid re-rendering duplicates
var cache: [String: NSBitmapImageRep] = [:]

for entry in entries {
    let key = "\(entry.pixelSize)-\(entry.roundedRect)"
    if cache[key] == nil {
        cache[key] = renderIcon(pixelSize: entry.pixelSize, applyRoundedRect: entry.roundedRect)
    }
    savePNG(rep: cache[key]!, to: "\(outputDir)/\(entry.filename)")
}

// MARK: - Generate Contents.json

func contentsJSON() -> String {
    var images: [[String: Any]] = []
    for entry in entries {
        var dict: [String: Any] = [
            "filename": entry.filename,
            "idiom": entry.idiom,
            "size": entry.size
        ]
        if let scale = entry.scale { dict["scale"] = scale }
        if let platform = entry.platform { dict["platform"] = platform }
        if let appearance = entry.appearance {
            dict["appearances"] = [["appearance": "luminosity", "value": appearance]]
        }
        images.append(dict)
    }

    let root: [String: Any] = [
        "images": images,
        "info": ["author": "xcode", "version": 1]
    ]

    let data = try! JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    return String(data: data, encoding: .utf8)!
}

let json = contentsJSON()
let jsonPath = "\(outputDir)/Contents.json"
try! json.write(toFile: jsonPath, atomically: true, encoding: .utf8)
print("  Wrote Contents.json")

print("Done! All icons generated in \(outputDir)/")
