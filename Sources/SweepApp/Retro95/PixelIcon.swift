import SwiftUI
import SweepKit

/// Original pixel drawings. A dot is transparent; all other characters use the shared palette.
struct PixelArt {
    let rows: [String]
    let palette: [Character: Color]
}

struct PixelIcon: View {
    let art: PixelArt
    /// 그림 칸 수의 정수배여야 한다. 아니면 안티앨리어싱 없이 칸이 들쭉날쭉해진다.
    var size: CGFloat = 16

    var body: some View {
        Canvas { context, _ in
            let columns = art.rows.first?.count ?? 0
            guard columns > 0 else { return }
            let cell = size / CGFloat(columns)
            for (y, row) in art.rows.enumerated() {
                for (x, symbol) in row.enumerated() where symbol != "." {
                    guard let color = art.palette[symbol] else { continue }
                    let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell,
                                      width: cell, height: cell)
                    context.fill(Path(rect), with: .color(color),
                                 style: FillStyle(antialiased: false))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension PixelArt {
    /// k black, w white, g silver, d gray, D charcoal, n navy, b blue,
    /// c teal, y yellow, Y gold shadow, r maroon, R red, G green, e beige.
    static let retroPalette: [Character: Color] = [
        "k": R95.black, "w": R95.white, "g": R95.gray,
        "d": R95.shadow, "D": R95.deep, "n": R95.navy,
        "b": R95.highlightBlue, "c": R95.teal, "y": R95.review,
        "Y": Color(hex: 0xC0A000), "r": R95.danger,
        "R": Color(hex: 0xFF0000), "G": R95.safe, "e": Color(hex: 0xE0D8B0),
    ]

    static let arrowUp = PixelArt(rows: [
        "................",
        ".......kk.......",
        "......knnk......",
        ".....knnnnk.....",
        "....knnnnnnk....",
        "...knnnnnnnnk...",
        "..kkkkknnkkkkk..",
        "......knnk......",
        "......knnk......",
        "......knnk......",
        "......knnk......",
        "......knnk......",
        "......kkkk......",
        "................",
        "................",
        "................",
    ], palette: retroPalette)

    /// 두 화살표와 가운데 여백으로 작은 크기에서도 새로고침을 알아보게 한다.
    static let refresh = PixelArt(rows: [
        "................",
        ".....nnnn.......",
        "...nnnnnnnn.....",
        "..nnn....nnn.n..",
        "..nn......nnnn..",
        ".nn.......nnnn..",
        ".nn......nnnnn..",
        ".nn.............",
        ".............nn.",
        "..nnnnn......nn.",
        "..nnnn.......nn.",
        "..nnnn......nn..",
        "..n.nnn....nnn..",
        ".....nnnnnnnn...",
        ".......nnnn.....",
        "................",
    ], palette: retroPalette)

    /// Raised program window with a navy title bar and a small document inside.
    static let application = PixelArt(rows: [
        "................",
        ".kkkkkkkkkkkkkk.",
        ".kwwwwwwwwwwwwk.",
        ".kwnnnnnnnnngdk.",
        ".kwnwnnnnnnngdk.",
        ".kwdddddddddddk.",
        ".kwgggggggggddk.",
        ".kwggkkkkkggddk.",
        ".kwggkwwwkggddk.",
        ".kwggkwnwkggddk.",
        ".kwggkwwwkggddk.",
        ".kwggkkkkkggddk.",
        ".kwgggggggggddk.",
        ".kddddddddddddk.",
        ".kkkkkkkkkkkkkk.",
        "................",
    ], palette: retroPalette)

    static let computer = PixelArt(rows: [
        "..kkkkkkkkkkkk..",
        "..kweeeeeeeeek..",
        "..kekkkkkkkkek..",
        "..kekwbbbbnkek..",
        "..kekbbbbbnkek..",
        "..kekbbbbbnkek..",
        "..keknnnnnnkek..",
        "..kekkkkkkkkek..",
        "..keeeeeeeYdek..",
        "..kkkkkkkkkkkk..",
        "......kedk......",
        ".kkkkkkkkkkkkk..",
        ".kweeeeeeeeedk..",
        ".kewggk.eeGddk..",
        ".kdddddddddddk..",
        ".kkkkkkkkkkkkk..",
    ], palette: retroPalette)

    static let computerLarge = PixelArt(rows: [
        "................................",
        "....kkkkkkkkkkkkkkkkkkkkkkkk....",
        "....kwwwwwwwwwwwwwwwwwwwwwwk....",
        "....kweeeeeeeeeeeeeeeeeeeedk....",
        "....kwekkkkkkkkkkkkkkkkkkedk....",
        "....kwekwwwwwwwwwwwwwwwwkedk....",
        "....kwekcbbbbbbbbbbbbbbbkedk....",
        "....kwekcbbbbbbbbbbbbbbbkedk....",
        "....kwekcbbbbbbbbbbbbbbbkedk....",
        "....kwekcbbbbbbbbbbbbbbbkedk....",
        "....kwekcbbbbbbbbbbbbbbbkedk....",
        "....kwekcbbbbbbbbbbbbbbbkedk....",
        "....kwekcbbbbbbbbbbbbbbbkedk....",
        "....kwekcbbbbbbbbbbbbbbbkedk....",
        "....kwekcbbbbbbbbbbbbbbbkedk....",
        "....kwekcbbbbbbbbbbbbbbbkedk....",
        "....kwekwdddddddddddddddkedk....",
        "....kwekkkkkkkkkkkkkkkkkkedk....",
        "....kweeeeeeeeeeeeeeeeeeeedk....",
        "....kweeeeeeeeeeeeeeeDDDeGdk....",
        "....kwdddddddddddddddddddddk....",
        "....kkkkkkkkkkkkkkkkkkkkkkkk....",
        ".............kkkkkk.............",
        ".............kwdddk.............",
        ".............kkkkkk.............",
        "..kkkkkkkkkkkkkkkkkkkkkkkkkkkk..",
        "..kwwwwwwwwwwwwwwwwwwwwwwwwwwk..",
        "..kwekkdddddddddkeeeeeeGGeeedk..",
        "..kwekwwwwwwwwwwkeeeeeeGGeyedk..",
        "..kwdddddddddddddddddddddddddk..",
        "..kkkkkkkkkkkkkkkkkkkkkkkkkkkk..",
        "................................",
    ], palette: retroPalette)

    static let magnifier = PixelArt(rows: [
        "................",
        "...kkkkk........",
        "..kwgggdk.......",
        ".kwggggddk......",
        ".kwgkkkgdk......",
        ".kwgkbkgdk......",
        ".kggkkkgdk......",
        "..kgggddk.......",
        "...kkkkkkk......",
        "......kwdk......",
        ".......kwdk.....",
        "........kwdk....",
        ".........kDDk...",
        "..........kDDk..",
        "...........kk...",
        "................",
    ], palette: retroPalette)

    static let folder = PixelArt(rows: [
        "................",
        ".kkkkkk.........",
        ".kwyyyk.........",
        ".kwyyykkkkkkkkk.",
        ".kwyyyyyyyyyyYk.",
        ".kwkkkkkkkkkkYk.",
        ".kkwyyyyyyyyYkk.",
        ".kwyyyyyyyyyYk..",
        ".kwyyyyyyyyyYk..",
        ".kwyyyyyyyyyYk..",
        ".kwyyyyyyyyyYk..",
        ".kwyyyyyyyyyYk..",
        ".kYYYYYYYYYYYk..",
        ".kkkkkkkkkkkk...",
        "................",
        "................",
    ], palette: retroPalette)

    static let documents = PixelArt(rows: [
        "................",
        "....kkkkkkkkk...",
        "....kwwwwwwdk...",
        "....kwDDDwwdk...",
        ".kkkkkkkkkwdk...",
        ".kwwwwwwdkDDk...",
        ".kwDDDwwdkwwk...",
        ".kwwwwwwdkDDk...",
        ".kwDDDDwdkwwk...",
        ".kwwwwwwdkddk...",
        ".kwDDDDwdkkkk...",
        ".kwwwwwwdk......",
        ".kwDDwwwdk......",
        ".kdddddddk......",
        ".kkkkkkkkk......",
        "................",
    ], palette: retroPalette)

    static let chip = PixelArt(rows: [
        "................",
        "....k.k.k.k.....",
        "....g.g.g.g.....",
        "...kkkkkkkkkk...",
        ".kgkwwwwwwwdkgk.",
        "...kwggggggdk...",
        ".kgkwgkkkkgdkgk.",
        "...kwgkwwkgdk...",
        ".kgkwgkddkgdkgk.",
        "...kwgkkkkgdk...",
        ".kgkwggggggdkgk.",
        "...kddddddddk...",
        "...kkkkkkkkkk...",
        "....d.d.d.d.....",
        "....k.k.k.k.....",
        "................",
    ], palette: retroPalette)

    static let devProject = PixelArt(rows: [
        "................",
        ".kkkkkkkkkkkkkk.",
        ".kggggggggggggk.",
        ".kgnnnnnnnnnngk.",
        ".kgnnnnnnnnwngk.",
        ".kgkkkkkkkkkkgk.",
        ".kgkkkkkkkkkkgk.",
        ".kgkGkkkkkkkkgk.",
        ".kgkkGkkkkkkkgk.",
        ".kgkkkGkkkkkkgk.",
        ".kgkkGkkkkkkkgk.",
        ".kgkGkkGGGkkkgk.",
        ".kgkkkkkkkkkkgk.",
        ".kggggggggggggk.",
        ".kkkkkkkkkkkkkk.",
        "................",
    ], palette: retroPalette)

    static let spaceView = PixelArt(rows: [
        "................",
        ".kkkkkkkkkkkkkk.",
        ".kcccccckyyyyyk.",
        ".kcccccckyyyyyk.",
        ".kcccccckyyyyyk.",
        ".kcccccckyyyyyk.",
        ".kcccccckyyyyyk.",
        ".kcccccckkkkkkk.",
        ".kcccccckRRkGGk.",
        ".kcccccckRRkGGk.",
        ".kcccccckRRkGGk.",
        ".kcccccckRRkGGk.",
        ".kcccccckRRkGGk.",
        ".kcccccckRRkGGk.",
        ".kkkkkkkkkkkkkk.",
        "................",
    ], palette: retroPalette)

    static let pieChart = PixelArt(rows: [
        "................",
        "................",
        ".....kkkkkk.....",
        "...kkwbbkkRkk...",
        "..kwbbbbkRRRrk..",
        ".kwbbbbbkRRRRrk.",
        ".kwbbbbbkRRRRrk.",
        ".kbbbbbbkRRRRrk.",
        ".kkkkkkkkkkkkkk.",
        ".kyyyyyykGGGGdk.",
        ".kwyyyyykGGGGdk.",
        "..kyyyyykGGGdk..",
        "...kYYYYkGddk...",
        ".....kkkkkk.....",
        "................",
        "................",
    ], palette: retroPalette)

    static let trash = PixelArt(rows: [
        "................",
        "......kkkk......",
        "......kwwk......",
        "..kkkkkkkkkkkk..",
        "..kwwwwwwwwddk..",
        "..kkkkkkkkkkkk..",
        "...kwgggggdk....",
        "...kwkgkgkdk....",
        "...kwkgkgkdk....",
        "...kwkgkgkdk....",
        "...kwkgkgkdk....",
        "...kwkgkgkdk....",
        "...kwkgkgkdk....",
        "...kdddddddk....",
        "...kkkkkkkkk....",
        "................",
    ], palette: retroPalette)

    static let warning = PixelArt(rows: [
        "................",
        ".......kk.......",
        "......kwyk......",
        "......kwyk......",
        ".....kwyyYk.....",
        ".....kwkkYk.....",
        "....kwykkYYk....",
        "....kwykkYYk....",
        "...kwyykkYYYk...",
        "...kwyykkYYYk...",
        "..kwyyyyyyyyYk..",
        "..kwyyykkYYYYk..",
        ".kwyyyykkYYYYYYk",
        ".kYYYYYYYYYYYYYk",
        ".kkkkkkkkkkkkkk.",
        "................",
    ], palette: retroPalette)

    static let lock = PixelArt(rows: [
        "................",
        ".....kkkkkk.....",
        "....kwgggddk....",
        "...kwgkkkkddk...",
        "...kwdk..kddk...",
        "...kwdk..kddk...",
        "...kwdk..kddk...",
        "..kkkkkkkkkkkk..",
        "..kwyyyyyyyyYk..",
        "..kwyyykkYYYYk..",
        "..kwyykDDkYYYk..",
        "..kwyyykkYYYYk..",
        "..kwyyykkYYYYk..",
        "..kYYYYYYYYYYk..",
        "..kkkkkkkkkkkk..",
        "................",
    ], palette: retroPalette)

    static let info = PixelArt(rows: [
        "................",
        ".....kkkkkk.....",
        "...kkwbbbbnkk...",
        "..kwbbbbbbbbnk..",
        ".kwbbbbwwbbbbnk.",
        ".kwbbbbwwbbbbnk.",
        ".kbbbbbbbbbbbnk.",
        ".kbbbbwwwbbbbnk.",
        ".kbbbbbwwbbbbnk.",
        ".kbbbbbwwbbbbnk.",
        ".kbbbbbwwbbbbnk.",
        "..kbbbwwwwbbnk..",
        "...kknnnnnnkk...",
        ".....kkkkkk.....",
        "................",
        "................",
    ], palette: retroPalette)

    static let broom = PixelArt(rows: [
        "...........kk...",
        "..........kwek..",
        ".........kwek...",
        "........kwek....",
        ".......kwek.....",
        "......kwek......",
        ".....kYek.......",
        "....kYYkk.......",
        "...kwyyyyk......",
        "..kwyyyyYk......",
        ".kwyyyyYYk......",
        ".kwyYyYyYk......",
        ".kyYyYyYYk......",
        ".kYYYYYYYk......",
        ".kkkkkkkk.......",
        "................",
    ], palette: retroPalette)

    static let hammer = PixelArt(rows: [
        "................",
        "...kkkkkkkkk....",
        "..kwgggggddkk...",
        "..kwgggggddDDk..",
        "..kdddddddkkDk..",
        "...kkkkdekk.kk..",
        "......kwek......",
        "......kwek......",
        ".....kwek.......",
        ".....kwek.......",
        "....kwek........",
        "....kwek........",
        "...kwek.........",
        "...kYdk.........",
        "....kk..........",
        "................",
    ], palette: retroPalette)

    static let box = PixelArt(rows: [
        "................",
        "......kkkk......",
        "....kkweeYkk....",
        "..kkweeeeeeYkk..",
        ".kwweeeeYeeeeYk.",
        ".kweeeeYkYeeeYk.",
        ".kkeeeYkkkYeYkk.",
        ".kweYkkYkYkkYYk.",
        ".kweekeeYkeeYYk.",
        ".kweekeeYkeeYYk.",
        ".kweekeeYkeeYYk.",
        "..kYkeeYkeeYkk..",
        "...kkYYYYYkk....",
        ".....kkkk.......",
        "................",
        "................",
    ], palette: retroPalette)

    static let globe = PixelArt(rows: [
        "................",
        "................",
        ".....kkkkkk.....",
        "...kkcckwcckk...",
        "..kwccckwcccdk..",
        ".kwccckcwkcccdk.",
        ".kwccckcwkcccdk.",
        ".kkkkkkkkkkkkkk.",
        ".kwccckcckcccdk.",
        ".kcccckcckcccdk.",
        ".kkkkkkkkkkkkkk.",
        "..kccckckcccdk..",
        "...kkcckccddk...",
        ".....kkkkkk.....",
        "................",
        "................",
    ], palette: retroPalette)

    static let clock = PixelArt(rows: [
        "................",
        "................",
        ".....kkkkkk.....",
        "...kkwggggdkk...",
        "..kwggggggggdk..",
        ".kwggggkgggggdk.",
        ".kwggggkgggggdk.",
        ".kgggggkgggggdk.",
        ".kgggggkkkkggdk.",
        ".kgggggggggggdk.",
        ".kgggggggggggdk.",
        "..kgggggggggdk..",
        "...kkddddddkk...",
        ".....kkkkkk.....",
        "................",
        "................",
    ], palette: retroPalette)

    static let bigFile = PixelArt(rows: [
        "..kkkkkkkkk.....",
        "..kwwwwwwkkk....",
        "..kwwwwwwkwdk...",
        "..kwDDDwwkkkk...",
        "..kwwwwwwwwdk...",
        "..kwDDDDwwwdk...",
        "..kwwwwwwwwdk...",
        "..kwDDwwwkkdk...",
        "..kwwwwwkbbkk...",
        "..kwwwwwkbbnk...",
        "..kddddkkbbnkk..",
        "..kkkkkkbbbbnk..",
        "........kbbnk...",
        ".........knk....",
        "..........k.....",
        "................",
    ], palette: retroPalette)

    static let hardDrive = PixelArt(rows: [
        "................",
        "................",
        "...kkkkkkkkkk...",
        "..kwggggggggdk..",
        ".kwggkkkkgggdk..",
        ".kwgkwggdkggdk..",
        ".kwgkgggdkggdk..",
        ".kwggkkkkgggdk..",
        ".kwgggggggggdk..",
        ".kwgggggggggdk..",
        ".kkkkkkkkkkkkk..",
        ".kwwggggggGgdk..",
        ".kdddddddddddk..",
        ".kkkkkkkkkkkkk..",
        "................",
        "................",
    ], palette: retroPalette)

    static let check = PixelArt(rows: [
        "................",
        "................",
        ".....kkkkkk.....",
        "...kkwGGGGdkk...",
        "..kwGGGGGGGGdk..",
        ".kwGGGGGGGwwGdk.",
        ".kwGGGGGGwwGGdk.",
        ".kGGwwGGwwGGGdk.",
        ".kGGGwwwwGGGGdk.",
        ".kGGGGwwGGGGGdk.",
        ".kGGGGGGGGGGGdk.",
        "..kGGGGGGGGGdk..",
        "...kkddddddkk...",
        ".....kkkkkk.....",
        "................",
        "................",
    ], palette: retroPalette)

    static let triangleRight = PixelArt(rows: [
        "................",
        "................",
        "................",
        ".....k..........",
        ".....kk.........",
        ".....kgk........",
        ".....kwgk.......",
        ".....kwgdk......",
        ".....kwgk.......",
        ".....kgk........",
        ".....kk.........",
        ".....k..........",
        "................",
        "................",
        "................",
        "................",
    ], palette: retroPalette)

    /// `triangleDown`을 위아래로 뒤집은 것. 표 헤더의 오름차순 표시.
    static let triangleUp = PixelArt(rows: [
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        ".......k........",
        "......kwk.......",
        ".....kwgdk......",
        "....kwgggdk.....",
        "...kkkkkkkkk....",
        "................",
        "................",
        "................",
        "................",
        "................",
    ], palette: retroPalette)

    static let triangleDown = PixelArt(rows: [
        "................",
        "................",
        "................",
        "................",
        "................",
        "...kkkkkkkkk....",
        "....kwgggdk.....",
        ".....kwgdk......",
        "......kdk.......",
        ".......k........",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ], palette: retroPalette)

}

extension Feature {
    var pixelArt: PixelArt {
        switch self {
        case .smartScan: .magnifier
        case .junk: .broom
        case .projects: .devProject
        case .largeFile: .folder
        case .duplicate: .documents
        case .trash: .trash
        case .applications: .application
        case .diskMap: .spaceView
        case .cpu: .chip
        }
    }
}

extension ScanCategory {
    var pixelArt: PixelArt {
        switch self {
        case .runawayTemp: .warning
        case .xcode: .hammer
        case .devCache: .box
        case .projectArtifact: .box
        case .appCache: .globe
        case .staleCache: .clock
        case .mailAttachment: .documents
        case .trash: .trash
        case .deviceBackup: .hardDrive
        case .largeFile: .bigFile
        case .duplicate: .documents
        case .application: .application
        }
    }
}

extension SafetyLevel {
    var pixelArt: PixelArt? {
        switch self {
        case .danger: .lock
        case .caution: .warning
        case .safe: nil
        }
    }
}

#if DEBUG
/// Standalone gallery for previews; deliberately not connected to app navigation.
struct PixelIconGallery: View {
    private let entries: [(name: String, art: PixelArt)] = [
        ("computer", .computer),
        ("application", .application),
        ("computerLarge", .computerLarge),
        ("magnifier", .magnifier),
        ("folder", .folder),
        ("documents", .documents),
        ("pieChart", .pieChart),
        ("trash", .trash),
        ("warning", .warning),
        ("lock", .lock),
        ("info", .info),
        ("broom", .broom),
        ("hammer", .hammer),
        ("box", .box),
        ("globe", .globe),
        ("clock", .clock),
        ("bigFile", .bigFile),
        ("hardDrive", .hardDrive),
        ("check", .check),
        ("triangleRight", .triangleRight),
        ("triangleDown", .triangleDown),
        ("triangleUp", .triangleUp),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112))], spacing: 16) {
                ForEach(entries.indices, id: \.self) { index in
                    VStack(spacing: 8) {
                        PixelIcon(art: entries[index].art, size: 32)
                        Text(entries[index].name).font(R95.mono(11))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
        .foregroundStyle(R95.black)
        .background(R95.gray)
    }
}

#Preview("Pixel icon gallery") {
    PixelIconGallery().frame(width: 560, height: 480)
}
#endif
