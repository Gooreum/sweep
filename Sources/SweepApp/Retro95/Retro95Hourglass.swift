import SwiftUI

/// Four sand levels followed by two quarter-turns, all on the original 16×16 grid.
struct Retro95Hourglass: View {
    var size: CGFloat = 16

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let frame = Int(context.date.timeIntervalSinceReferenceDate * 4) % Self.frames.count
            PixelIcon(art: Self.frames[frame], size: size)
        }
        .accessibilityHidden(true)
    }

    static let frames: [PixelArt] = {
        let outline = [
            "................", "...kkkkkkkkkk...", "...kwwwwwwwdk...",
            "....kwwwwddk....", "....kwwwwddk....", ".....kwwddk.....",
            "......kddk......", ".......kk.......", ".......kk.......",
            "......kwwk......", ".....kwwwwk.....", "....kwwwwwwk....",
            "....kwwwwwwk....", "...kwwwwwwwdk...", "...kkkkkkkkkk...",
            "................",
        ]
        let levels: [[(Int, ClosedRange<Int>)]] = [
            [(3, 5...10), (4, 5...10), (5, 6...9), (6, 7...8)],
            [(4, 5...10), (5, 6...9), (6, 7...8), (12, 7...8)],
            [(5, 6...9), (6, 7...8), (11, 7...8), (12, 6...9)],
            [(10, 7...8), (11, 6...9), (12, 5...10)],
        ]
        var arts = levels.enumerated().map { index, sand in
            var grid = outline.map(Array.init)
            for (y, xs) in sand {
                for x in xs { grid[y][x] = "y" }
            }
            if index == 1 || index == 2 {
                grid[8][7] = "Y"
                grid[9][7] = "y"
            }
            return PixelArt(rows: grid.map { String($0) }, palette: PixelArt.retroPalette)
        }
        let filled = arts[3].rows.map(Array.init)
        // Rasterized rotations avoid blurred intermediate pixels at 16pt.
        for angle in [Double.pi / 2, Double.pi] {
            var grid = Array(repeating: Array(repeating: Character("."), count: 16), count: 16)
            for y in 0..<16 {
                for x in 0..<16 {
                    let dx = Double(x) - 7.5, dy = Double(y) - 7.5
                    let sx = Int((cos(angle) * dx + sin(angle) * dy + 7.5).rounded())
                    let sy = Int((-sin(angle) * dx + cos(angle) * dy + 7.5).rounded())
                    if (0..<16).contains(sx), (0..<16).contains(sy) { grid[y][x] = filled[sy][sx] }
                }
            }
            arts.append(PixelArt(rows: grid.map { String($0) }, palette: PixelArt.retroPalette))
        }
        return arts
    }()
}
