#!/usr/bin/env swift
//
//  앱 아이콘을 그려 `dist/AppIcon.icns`를 만든다.
//
//  이미지 파일을 저장소에 넣는 대신 코드로 그리는 이유: 색을 바꾸면 앱과
//  아이콘이 따로 놀 수 있는데, 여기 값과 `Theme`의 값이 같은 자리에 적혀 있으면
//  적어도 어긋난 것을 눈으로 찾을 수 있다.
//
//  SF Symbols는 Apple 라이선스상 앱 아이콘·로고로 쓸 수 없어 직접 그린다.
//
//  나중에 제대로 된 이미지가 생기면 이 스크립트를 지우고 `.icns`만 넣으면 된다.
//
//  실행: swift scripts/make-icon.swift
//
import AppKit
import CoreGraphics
import Foundation

// MARK: - 색 (앱이 쓰는 값과 같아야 한다)

/// `Theme.accent`(#0A5FFF) 계열. 아이콘은 작게 보이므로 위쪽을 조금 밝게 잡는다.
let topBlue = CGColor(red: 0.161, green: 0.451, blue: 1.0, alpha: 1)
let bottomBlue = CGColor(red: 0.039, green: 0.239, blue: 0.780, alpha: 1)
/// `Feature.diskMap`의 다크 색 #7ED88F.
let reclaimedGreen = CGColor(red: 0.494, green: 0.847, blue: 0.561, alpha: 1)

// MARK: - 그리기

func draw(_ px: Int) -> CGImage {
    let s = CGFloat(px)
    guard let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fatalError("컨텍스트를 만들지 못했다: \(px)px") }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Big Sur 이후 아이콘은 여백을 둔 스퀘어클이다.
    // 꽉 채우면 Dock에서 이 앱만 혼자 커 보인다.
    let inset = s * 0.09
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let squircle = CGPath(roundedRect: rect,
                          cornerWidth: rect.width * 0.225,
                          cornerHeight: rect.height * 0.225,
                          transform: nil)

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [topBlue, bottomBlue] as CFArray,
                                 locations: [0, 1]) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: s),
                               end: CGPoint(x: 0, y: 0),
                               options: [])
    }
    ctx.restoreGState()

    // 도넛 고리. 이 앱의 대표 화면이고 16px에서도 고리로 읽힌다.
    // 12시에서 시계방향 300° — 남은 60°가 "비운 만큼"이다.
    let center = CGPoint(x: s / 2, y: s / 2)
    let radius = s * 0.245
    let gapStart = CGFloat.pi / 2                       // 12시
    let gapEnd = gapStart - (300 * .pi / 180)

    ctx.setLineWidth(s * 0.115)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.addArc(center: center, radius: radius,
               startAngle: gapStart, endAngle: gapEnd, clockwise: true)
    ctx.strokePath()

    // 틈 **한가운데**에 초록 점 — 회수한 공간.
    //
    // 고리 끝에 붙이면 `.round` 캡과 겹쳐 혹처럼 보인다. 틈의 중앙(끝에서 30° 더)
    // 으로 밀어야 고리와 분리된 별개 요소로 읽힌다.
    //
    // 16px에서는 뭉개지므로 그리지 않는다. 있으나 마나 한 픽셀이 형태만 흐린다.
    if px >= 32 {
        let dot = s * 0.10
        let angle = gapEnd - (30 * .pi / 180)
        ctx.setFillColor(reclaimedGreen)
        ctx.fillEllipse(in: CGRect(x: center.x + cos(angle) * radius - dot / 2,
                                   y: center.y + sin(angle) * radius - dot / 2,
                                   width: dot, height: dot))
    }

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
let iconset = dist.appending(path: "AppIcon.iconset")

// `dist/`가 없어도 돌아야 한다 — 새로 받은 저장소에는 없다.
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for step in steps {
    let image = draw(step.px)
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: step.px, height: step.px)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG로 못 바꿨다: \(step.name)")
    }
    try png.write(to: iconset.appending(path: "\(step.name).png"))
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
