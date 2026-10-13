#!/usr/bin/env swift
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct Copy: Decodable { let headline: String; let subhead: String }
struct Shot: Decodable { let stage: String; let ko: Copy; let en: Copy }
enum Failure: Error { case message(String) }
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("오류: " + message + "\n").utf8))
    exit(1)
}
func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
let width = 2880, height = 1800
// All drawing uses top-left coordinates in an explicitly allocated 1x sRGB bitmap.
func fill(_ rect: CGRect, _ shade: NSColor) { shade.setFill(); rect.fill() }
func bevel(_ rect: CGRect) {
    for (inset, light, dark) in [(CGFloat(0), UInt32(0xDFDFDF), UInt32(0)),
                                (CGFloat(4), UInt32(0xFFFFFF), UInt32(0x808080))] {
        let r = rect.insetBy(dx: inset, dy: inset)
        fill(CGRect(x: r.minX, y: r.minY, width: r.width, height: 4), color(light))
        fill(CGRect(x: r.minX, y: r.minY, width: 4, height: r.height), color(light))
        fill(CGRect(x: r.minX, y: r.maxY - 4, width: r.width, height: 4), color(dark))
        fill(CGRect(x: r.maxX - 4, y: r.minY, width: 4, height: r.height), color(dark))
    }
}
func gradient(_ rect: CGRect, from: UInt32, to: UInt32, start: CGPoint, end: CGPoint) {
    NSGraphicsContext.current!.cgContext.saveGState()
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.clip(to: rect)
    let ramp = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [color(from).cgColor, color(to).cgColor] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(ramp, start: start, end: end,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}
func font(_ size: CGFloat, bold: Bool) -> NSFont {
    let base = NSFont(name: "Geneva", size: size) ?? NSFont.systemFont(ofSize: size)
    return bold ? NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask) : base
}
func text(_ value: String, in rect: CGRect, size: CGFloat, bold: Bool, shade: NSColor) {
    var pointSize = size
    var string: NSAttributedString
    repeat {
        var attributes: [NSAttributedString.Key: Any] = [.font: font(pointSize, bold: bold),
                                                        .foregroundColor: shade]
        // Geneva has no native bold face on some macOS versions.
        // A light fill-and-stroke preserves Geneva and strengthens fallback glyphs too.
        if bold {
            attributes[.strokeColor] = shade
            attributes[.strokeWidth] = -2
        }
        string = NSAttributedString(string: value, attributes: attributes)
        if string.size().width <= rect.width && string.size().height <= rect.height { break }
        pointSize -= 1
    } while pointSize > 1
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.setShouldAntialias(true)
    string.draw(at: CGPoint(x: rect.minX, y: rect.midY - string.size().height / 2))
    ctx.restoreGState()
}
func computer(at origin: CGPoint) {
    // Sixteen-square pixel grid; each cell occupies seven output pixels.
    let rows = [
        "................", ".############...", ".#WWWWWWWWWW#...", ".#W########W#...",
        ".#W#BBBBBB#W#...", ".#W#BBBBBB#W#...", ".#W#BBBBBB#W#...", ".#W#BBBBBB#W#...",
        ".#W########W#...", ".#WWWWWWWWWW#...", ".############...", "......##........",
        "..###########...", "..#WWWWWWGGW#...", "..###########...", "................"
    ]
    let palette: [Character: NSColor] = ["#": color(0), "W": color(0xFFFFFF),
                                        "B": color(0x000080), "G": color(0x008000)]
    for (y, row) in rows.enumerated() {
        for (x, pixel) in row.enumerated() {
            if let shade = palette[pixel] {
                fill(CGRect(x: origin.x + CGFloat(x * 7), y: origin.y + CGFloat(y * 7),
                            width: 7, height: 7), shade)
            }
        }
    }
}
func buttons(at origin: CGPoint) {
    for index in 0..<3 {
        let r = CGRect(x: origin.x + CGFloat(index * 80), y: origin.y, width: 72, height: 72)
        fill(r, color(0xC0C0C0)); bevel(r)
        let x = r.minX, y = r.minY
        switch index {
        case 0: fill(CGRect(x: x + 20, y: y + 48, width: 32, height: 6), color(0))
        case 1:
            fill(CGRect(x: x + 20, y: y + 20, width: 32, height: 32), color(0))
            fill(CGRect(x: x + 26, y: y + 28, width: 20, height: 18), color(0xC0C0C0))
        default:
            for cell in 0..<6 {
                fill(CGRect(x: x + 18 + CGFloat(cell * 6), y: y + 18 + CGFloat(cell * 6),
                            width: 6, height: 6), color(0))
                fill(CGRect(x: x + 48 - CGFloat(cell * 6), y: y + 18 + CGFloat(cell * 6),
                            width: 6, height: 6), color(0))
            }
        }
    }
}
func render(_ shot: Shot, language: String, source: CGImage, output: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                              bytesPerRow: width * 4, space: space,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw Failure.message("출력 비트맵을 만들 수 없습니다.")
    }
    ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    defer { NSGraphicsContext.restoreGraphicsState() }
    ctx.setShouldAntialias(false)
    // CSS-style 160 degrees: the darkward vector points down and right.
    let angle = CGFloat(160) * .pi / 180
    let direction = CGPoint(x: sin(angle), y: -cos(angle))
    let extent = (CGFloat(width) * abs(direction.x) + CGFloat(height) * abs(direction.y)) / 2
    let center = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
    gradient(CGRect(x: 0, y: 0, width: width, height: height), from: 0x008080, to: 0x004040,
             start: CGPoint(x: center.x - direction.x * extent, y: center.y - direction.y * extent),
             end: CGPoint(x: center.x + direction.x * extent, y: center.y + direction.y * extent))
    let captureY: CGFloat = 418
    let scale = min(2600 / CGFloat(source.width), 1312 / CGFloat(source.height))
    let capture = CGRect(x: (CGFloat(width) - CGFloat(source.width) * scale) / 2,
                         y: captureY, width: CGFloat(source.width) * scale,
                         height: CGFloat(source.height) * scale)
    let dialog = CGRect(x: capture.minX, y: 60, width: capture.width, height: 298)
    for r in [dialog, capture] { fill(r.offsetBy(dx: 24, dy: 24), color(0, alpha: 0.55)) }
    fill(dialog, color(0xC0C0C0)); bevel(dialog)
    let title = CGRect(x: dialog.minX + 8, y: dialog.minY + 8, width: dialog.width - 16, height: 150)
    gradient(title, from: 0x000080, to: 0x1084D0,
             start: CGPoint(x: title.minX, y: title.minY), end: CGPoint(x: title.maxX, y: title.minY))
    computer(at: CGPoint(x: title.minX + 20, y: title.minY + 19))
    let buttonX = title.maxX - 252
    buttons(at: CGPoint(x: buttonX, y: title.midY - 36))
    let copy = language == "ko" ? shot.ko : shot.en
    let textX = title.minX + 152
    text(copy.headline, in: CGRect(x: textX, y: title.minY + 12,
                                  width: buttonX - textX - 28, height: 126),
         size: 84, bold: true, shade: .white)
    text(copy.subhead, in: CGRect(x: textX, y: title.maxY + 12,
                                 width: title.maxX - textX - 24, height: 116),
         size: 54, bold: false, shade: .black)
    // CGImage drawing needs its own vertical inversion inside the flipped canvas.
    ctx.saveGState()
    ctx.translateBy(x: capture.minX, y: capture.maxY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    ctx.draw(source, in: CGRect(origin: .zero, size: capture.size))
    ctx.restoreGState()
    guard let image = ctx.makeImage(),
          let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw Failure.message("PNG 출력 파일을 만들 수 없습니다: \(output.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw Failure.message("PNG 저장에 실패했습니다: \(output.path)")
    }
}
let args = CommandLine.arguments
guard args.count == 4, ["ko", "en"].contains(args[1]) else {
    fail("사용법: swift scripts/store-screenshots.swift <ko|en> <캡처 폴더> <출력 폴더>")
}
do {
    let config = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("scripts/store-screenshots.json")
    let shots = try JSONDecoder().decode([Shot].self, from: Data(contentsOf: config))
    guard shots.count == 6 else { throw Failure.message("스크린샷 정의는 6장이어야 합니다.") }
    let input = URL(fileURLWithPath: args[2], isDirectory: true)
    // Check every capture before creating any output.
    let sources = try shots.map { shot -> CGImage in
        let url = input.appendingPathComponent(shot.stage + ".png")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw Failure.message("캡처를 읽을 수 없습니다: \(url.path)")
        }
        return image
    }
    let output = URL(fileURLWithPath: args[3], isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for (index, shot) in shots.enumerated() {
        try autoreleasepool {
            try render(shot, language: args[1], source: sources[index],
                       output: output.appendingPathComponent(String(format: "%02d.png", index + 1)))
        }
    }
    print("\(args[1]) 스크린샷 6장 저장 완료: \(output.path)")
} catch Failure.message(let message) { fail(message) }
catch { fail("스크린샷 생성에 실패했습니다: \(error.localizedDescription)") }
