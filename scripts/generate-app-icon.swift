#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let previewURL = resources.appendingPathComponent("AppIconPreview.png")
let icnsURL = resources.appendingPathComponent("AppIcon.icns")

try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func fillCapsule(_ rect: CGRect, in context: CGContext) {
    let diameter = min(rect.width, rect.height)
    if rect.height >= rect.width {
        context.fill(CGRect(x: rect.minX, y: rect.minY + diameter / 2, width: rect.width, height: rect.height - diameter))
        context.fillEllipse(in: CGRect(x: rect.minX, y: rect.minY, width: diameter, height: diameter))
        context.fillEllipse(in: CGRect(x: rect.minX, y: rect.maxY - diameter, width: diameter, height: diameter))
    } else {
        context.fill(CGRect(x: rect.minX + diameter / 2, y: rect.minY, width: rect.width - diameter, height: rect.height))
        context.fillEllipse(in: CGRect(x: rect.minX, y: rect.minY, width: diameter, height: diameter))
        context.fillEllipse(in: CGRect(x: rect.maxX - diameter, y: rect.minY, width: diameter, height: diameter))
    }
}

func drawIcon(in context: CGContext) {
    let bounds = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    context.clear(bounds)

    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(38, 32, 55), color(11, 13, 21)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 250, y: 980),
        end: CGPoint(x: 800, y: 40),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(153, 130, 237, 0.22), color(153, 130, 237, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: 510, y: 520),
        startRadius: 20,
        endCenter: CGPoint(x: 510, y: 520),
        endRadius: 430,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    let center = CGPoint(x: 512, y: 480)
    let radius: CGFloat = 250
    let start = CGFloat.pi * 0.22
    let end = CGFloat.pi * 1.78

    context.setLineCap(.round)
    context.setStrokeColor(color(64, 58, 83, 0.92))
    context.setLineWidth(98)
    context.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
    context.strokePath()

    context.setStrokeColor(color(166, 143, 239))
    context.setLineWidth(78)
    context.addArc(center: center, radius: radius, startAngle: start, endAngle: CGFloat.pi * 1.51, clockwise: false)
    context.strokePath()

    let bars: [(CGRect, CGColor)] = [
        (CGRect(x: 392, y: 384, width: 48, height: 112), color(214, 211, 225)),
        (CGRect(x: 462, y: 384, width: 48, height: 178), color(184, 166, 242)),
        (CGRect(x: 532, y: 384, width: 48, height: 142), color(238, 237, 244)),
        (CGRect(x: 602, y: 384, width: 48, height: 214), color(166, 143, 239))
    ]
    for (rect, fill) in bars {
        context.setFillColor(fill)
        fillCapsule(rect, in: context)
    }

    context.setFillColor(color(255, 155, 73))
    context.fillEllipse(in: CGRect(x: 731, y: 567, width: 78, height: 78))
    context.setStrokeColor(color(255, 220, 190, 0.72))
    context.setLineWidth(7)
    context.strokeEllipse(in: CGRect(x: 731, y: 567, width: 78, height: 78))

    context.setFillColor(color(0, 0, 0))
    fillCapsule(CGRect(x: 336, y: 848, width: 352, height: 132), in: context)

    context.setFillColor(color(32, 34, 40))
    context.fillEllipse(in: CGRect(x: 618, y: 897, width: 28, height: 28))
    context.setFillColor(color(72, 79, 102, 0.8))
    context.fillEllipse(in: CGRect(x: 626, y: 905, width: 10, height: 10))

}

func renderPNG(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "AppIconGenerator", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    graphics.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(in: graphics.cgContext)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIconGenerator", code: 2)
    }
    return data
}

let variants: [(String, Int)] = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024)
]

try renderPNG(size: 1024).write(to: previewURL)

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

var chunks = Data()
for (type, size) in variants {
    let png = try renderPNG(size: size)
    chunks.append(type.data(using: .ascii)!)
    appendBigEndian(UInt32(png.count + 8), to: &chunks)
    chunks.append(png)
}

var icns = Data("icns".utf8)
appendBigEndian(UInt32(chunks.count + 8), to: &icns)
icns.append(chunks)
try icns.write(to: icnsURL)

print("已生成：\(previewURL.path)")
print("已生成：\(icnsURL.path)")
