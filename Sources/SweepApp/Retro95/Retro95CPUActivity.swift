import SwiftUI

/// 작업 관리자처럼 네 개의 초록 막대가 움직이는 16×16 픽셀 미터.
struct Retro95CPUActivity: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let frame = Int(context.date.timeIntervalSinceReferenceDate * 5) % Self.frames.count
            PixelIcon(art: Self.frames[frame], size: 16)
        }
        .accessibilityHidden(true)
    }

    static let frames: [PixelArt] = {
        let outline = [
            "................",
            ".wwwwwwwwwwwwww.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".wkkkkkkkkkkkkd.",
            ".dddddddddddddd.",
            "................",
        ]
        let levels = [
            [2, 4, 3, 1],
            [3, 5, 2, 2],
            [5, 3, 1, 4],
            [4, 2, 3, 5],
            [2, 3, 5, 3],
        ]
        return levels.map { heights in
            var grid = outline.map(Array.init)
            for (bar, height) in heights.enumerated() {
                let x = 2 + bar * 3
                for level in 0..<height {
                    let y = 12 - level * 2
                    grid[y][x] = "G"
                    grid[y][x + 1] = "G"
                }
            }
            return PixelArt(rows: grid.map { String($0) }, palette: PixelArt.retroPalette)
        }
    }()
}
