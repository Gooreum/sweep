#!/usr/bin/env swift
//
//  `Resources/AppIcon.png`(픽셀 아트 원본)를 크기별로 줄여
//  `dist/AppIcon.icns`와 App Store용 자산 카탈로그를 만든다.
//
//  실행: swift scripts/make-icon.swift
//
import AppKit
import CoreGraphics
import Foundation

// MARK: - 그리기

/// 원본 아이콘. 1024×1024, 바깥은 투명하고 본체는 macOS 격자(824px, 여백 100px)에 맞춰 두었다.
let source: CGImage = {
    let url = URL(filePath: FileManager.default.currentDirectoryPath)
        .appending(path: "Resources/AppIcon.png")
    guard let image = NSImage(contentsOf: url)?
        .cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { fatalError("원본 아이콘을 읽지 못했다: \(url.path)") }
    return image
}()

/// 원본을 크기별로 줄인다. 픽셀 아트라 작은 크기에서도 고품질 보간으로 줄여야 뭉개짐이 덜하다.
func draw(_ px: Int) -> CGImage {
    guard let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fatalError("컨텍스트를 만들지 못했다: \(px)px") }
    ctx.interpolationQuality = .high
    ctx.draw(source, in: CGRect(x: 0, y: 0, width: px, height: px))
    guard let image = ctx.makeImage() else { fatalError("이미지를 못 만들었다") }
    return image
}

// MARK: - 내보내기

/// `iconutil`이 이 파일명을 그대로 요구한다. 하나라도 빠지면 거부한다.
let steps: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let fm = FileManager.default
let root = URL(filePath: fm.currentDirectoryPath)
let dist = root.appending(path: "dist")

/// PNG 한 장을 그려 파일로 쓴다. 두 갈래가 같은 그림을 써야 하므로 여기 모은다.
func writePNG(_ step: (name: String, px: Int), to directory: URL) throws {
    let image = draw(step.px)
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: step.px, height: step.px)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG로 못 바꿨다: \(step.name)")
    }
    try png.write(to: directory.appending(path: "\(step.name).png"))
}

// MARK: - --appiconset: App Store용 자산 카탈로그
//
// App Store 업로드는 **자산 카탈로그 안의 아이콘**을 요구한다. `.icns`만 넣으면
// 검증에서 막힌다. 직접 배포(`make-app.sh`)는 `.icns`를 쓰므로 둘 다 필요하다.
//
// `steps`의 10종이 macOS appiconset이 요구하는 크기와 정확히 같아 그림은 공유한다.
// 파일명의 `@2x`가 곧 scale이고, 앞의 숫자가 size다 — Contents.json은 여기서 유도한다.

if CommandLine.arguments.contains("--appiconset") {
    let appiconset = root.appending(path: "Resources/Assets.xcassets/AppIcon.appiconset")

    try? fm.removeItem(at: appiconset)
    try fm.createDirectory(at: appiconset, withIntermediateDirectories: true)

    var images: [String] = []
    for step in steps {
        try writePNG(step, to: appiconset)

        // "icon_128x128@2x" → size "128x128", scale "2x"
        let body = step.name.replacingOccurrences(of: "icon_", with: "")
        let parts = body.split(separator: "@", maxSplits: 1)
        let size = String(parts[0])
        let scale = parts.count > 1 ? String(parts[1]) : "1x"

        images.append("""
            {
              "filename" : "\(step.name).png",
              "idiom" : "mac",
              "scale" : "\(scale)",
              "size" : "\(size)"
            }
        """)
    }

    let contents = """
    {
      "images" : [
    \(images.joined(separator: ",\n"))
      ],
      "info" : {
        "author" : "make-icon.swift",
        "version" : 1
      }
    }

    """
    try contents.write(to: appiconset.appending(path: "Contents.json"),
                       atomically: true, encoding: .utf8)

    // 카탈로그 루트에도 Contents.json이 있어야 Xcode가 카탈로그로 인식한다.
    let catalog = root.appending(path: "Resources/Assets.xcassets")
    try """
    {
      "info" : {
        "author" : "make-icon.swift",
        "version" : 1
      }
    }

    """.write(to: catalog.appending(path: "Contents.json"), atomically: true, encoding: .utf8)

    print("만듦: \(appiconset.path) (PNG \(steps.count)장 + Contents.json)")
    exit(0)
}

// MARK: - 기본: 직접 배포용 .icns

let iconset = dist.appending(path: "AppIcon.iconset")

// `dist/`가 없어도 돌아야 한다 — 새로 받은 저장소에는 없다.
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for step in steps {
    try writePNG(step, to: iconset)
}

let icns = dist.appending(path: "AppIcon.icns")
let convert = Process()
convert.executableURL = URL(filePath: "/usr/bin/iconutil")
convert.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try convert.run()
convert.waitUntilExit()
guard convert.terminationStatus == 0 else {
    fatalError("iconutil 실패: \(convert.terminationStatus)")
}

// .iconset은 중간 산출물이다. 남겨 두면 dist를 볼 때 뭐가 결과물인지 헷갈린다.
try? fm.removeItem(at: iconset)

let bytes = (try? fm.attributesOfItem(atPath: icns.path))?[.size] as? Int ?? 0
print("만듦: \(icns.path) (\(bytes) bytes, \(steps.count)단계)")
