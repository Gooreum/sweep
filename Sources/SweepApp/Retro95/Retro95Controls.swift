import SwiftUI
import SweepKit

struct Retro95ButtonStyle: ButtonStyle {
    var isDefault = false

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, isDefault: isDefault)
    }

    /// 상태 저장소가 뷰 그래프에 설치되도록 hover를 중첩 뷰에서 관리한다.
    private struct StyledLabel: View {
        let configuration: ButtonStyleConfiguration
        let isDefault: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @Environment(\.displayScale) private var displayScale
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(R95.ui(12, bold: isDefault))
                .foregroundStyle(isEnabled ? R95.black : R95.shadow)
                .background(alignment: .topLeading) {
                    if !isEnabled {
                        // 글꼴을 같이 줘야 한다. 빠지면 시스템 글꼴로 그려져 음각 그림자가 어긋나 겹친다.
                        configuration.label
                            .font(R95.ui(12, bold: isDefault))
                            .foregroundStyle(R95.white)
                            .offset(x: 1, y: 1)
                            .accessibilityHidden(true)
                    }
                }
                .offset(x: pressed ? 1 : 0, y: pressed ? 1 : 0)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(minHeight: R95.buttonHeight)
                .background(isHovering && isEnabled ? R95.light : R95.gray)
                .retroBevel(pressed ? .pressed : .raised)
                .overlay {
                    if isFocused && isEnabled {
                        Rectangle().inset(by: 4)
                            .strokeBorder(R95.black, style: StrokeStyle(lineWidth: 1 / displayScale, dash: [1, 1]))
                            .allowsHitTesting(false)
                    }
                }
                .padding(isDefault ? 1 / displayScale : 0)
                .background(R95.black)
                .onHover { isHovering = $0 }
        }

        private var pressed: Bool { configuration.isPressed && isEnabled }
    }
}

enum Retro95CheckState { case off, on, mixed }

/// 행마다 네이티브 컨트롤을 만들지 않아 긴 목록의 스크롤 비용을 줄인다.
struct Retro95Checkbox: View {
    let state: Retro95CheckState

    var body: some View {
        Canvas { context, size in
            if state == .on {
                let cells = [(2, 6), (3, 7), (4, 8), (5, 7), (6, 6), (7, 5), (8, 4), (9, 3)]
                var check = Path()
                for (x, y) in cells {
                    check.addRect(CGRect(x: x, y: y, width: 1, height: 2))
                }
                context.fill(check, with: .color(R95.navy))
            } else if state == .mixed {
                context.fill(Path(CGRect(x: 3, y: 3, width: size.width - 6, height: size.height - 6)), with: .color(R95.shadow))
            }
        }
        .frame(width: R95.checkboxSize, height: R95.checkboxSize)
        .background(R95.white)
        .retroSunken()
        .accessibilityLabel(state == .on ? "선택됨" : state == .mixed ? "부분 선택됨" : "선택 안 됨")
    }
}

struct Retro95ProgressBar: View {
    let fraction: Double?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: fraction != nil)) { timeline in
            Canvas { context, size in
                let block: CGFloat = 10
                let step: CGFloat = 12
                let slots = max(0, Int((size.width + 2) / step))
                let bounded = fraction.map { $0.isFinite ? min(1, max(0, $0)) : 0 }
                let filled = bounded.map { Int(ceil($0 * Double(slots))) }
                let travel = max(0, slots - 4)
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 1.2
                let start = Int((phase <= 1 ? phase : 2 - phase) * Double(travel))
                for index in 0..<slots {
                    let visible = filled.map { index < $0 } ?? (index >= start && index < start + 4)
                    if visible {
                        context.fill(Path(CGRect(x: CGFloat(index) * step, y: 0, width: block, height: size.height)), with: .color(R95.navy))
                    }
                }
            }
            .padding(3)
        }
        .frame(height: 20)
        .background(R95.white)
        .retroSunken()
        .accessibilityLabel("진행률")
        .accessibilityValue(fraction.map { "\(Int(($0.isFinite ? min(1, max(0, $0)) : 0) * 100))%" } ?? "진행 중")
    }
}

struct Retro95GroupBox<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(title).font(R95.ui(13, bold: true)).foregroundStyle(R95.white)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(R95.navy)
                Rectangle().fill(R95.navy).frame(height: 3)
            }
            content.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(R95.gray)
        .retroBevel(.groove)
    }
}

struct Retro95StatusBar: View {
    struct Segment {
        let text: String
        var width: CGFloat? = nil
    }
    let segments: [Segment]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(segments.indices, id: \.self) { index in
                Text(segments[index].text).font(R95.ui(11)).foregroundStyle(R95.black)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(width: segments[index].width, height: R95.statusBarHeight - 4, alignment: .leading)
                    .frame(maxWidth: segments[index].width == nil ? .infinity : nil, alignment: .leading)
                    .retroBevel(.field)
            }
            Canvas { context, _ in
                for row in 0..<3 {
                    for column in 0...row {
                        let rect = CGRect(x: 10 - column * 4, y: 3 + row * 4, width: 2, height: 2)
                        context.fill(Path(rect.offsetBy(dx: 1, dy: 1)), with: .color(R95.white))
                        context.fill(Path(rect), with: .color(R95.shadow))
                    }
                }
            }.frame(width: 16, height: 16).accessibilityHidden(true)
        }
        .padding(.horizontal, 2)
        .frame(height: R95.statusBarHeight)
        .background(R95.gray)
    }
}

struct Retro95TitleStrip: View {
    let title: String
    var icon: PixelArt? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                PixelIcon(art: icon)
            }
            Text(title).font(R95.ui(13, bold: true)).foregroundStyle(R95.white)
                .lineLimit(1)
        }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: R95.titleStripHeight).background(R95.navy)
    }
}

struct SafetyChip: View {
    let level: SafetyLevel
    var compact = false
    private var label: String {
        switch level { case .safe: "SAFE"; case .caution: "REVIEW"; case .danger: "DANGER" }
    }
    private var fill: Color {
        switch level { case .safe: R95.safe; case .caution: R95.review; case .danger: R95.danger }
    }
    var body: some View {
        HStack(spacing: 2) {
            if level == .danger, let art = level.pixelArt {
                PixelIcon(art: art, size: 16)
            }
            Text(label).font(R95.ui(compact ? 9 : 11, bold: true))
        }
        .foregroundStyle(level == .caution ? R95.black : R95.white)
        .frame(width: compact ? (level == .danger ? 62 : 50) : (level == .danger ? 76 : 64), height: 20)
        .background(fill).retroBevel(.field)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level.displayName)
    }
}

struct Retro95TableHeader: View {
    struct Column {
        let title: String
        var width: CGFloat? = nil
        var alignment: Alignment = .leading
        /// 있으면 이 열의 왼쪽 경계를 끌 수 있다. 오른쪽으로 끈 거리(+)를 조금씩 넘긴다.
        var onResizeLeadingEdge: (@MainActor (CGFloat) -> Void)? = nil
        /// 있으면 칸을 눌러 이 열로 정렬한다.
        var onSort: (@MainActor () -> Void)? = nil
        /// 지금 이 열로 정렬 중이면 방향. true면 ▲(오름차순).
        var sortAscending: Bool? = nil
    }
    let columns: [Column]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns.indices, id: \.self) { index in
                cell(columns[index])
                    // 뒤에 오는 열이 위에 그려지므로 왼쪽 열의 끝까지 손잡이가 덮는다.
                    // 손잡이가 버튼보다 위라 경계를 끌어도 정렬이 바뀌지 않는다.
                    .overlay(alignment: .leading) {
                        if let onResize = columns[index].onResizeLeadingEdge {
                            ColumnResizeHandle(onDrag: onResize).offset(x: -4)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func cell(_ column: Column) -> some View {
        if let onSort = column.onSort {
            Button(action: onSort) {
                // 누르는 동안은 ButtonStyle이 눌린 베벨을 그린다.
                EmptyView()
            }
            .buttonStyle(HeaderCellStyle(column: column))
            .accessibilityLabel(column.title)
            .accessibilityHint(Text("정렬"))
        } else {
            HeaderCellLabel(column: column, isPressed: false)
        }
    }

    /// 헤더 칸 전체가 누르는 면이다. 글자만 누를 수 있으면 넓은 칸에서 헛누르게 된다.
    private struct HeaderCellStyle: ButtonStyle {
        let column: Column
        func makeBody(configuration: Configuration) -> some View {
            HeaderCellLabel(column: column, isPressed: configuration.isPressed)
                .contentShape(Rectangle())
        }
    }

    private struct HeaderCellLabel: View {
        let column: Column
        let isPressed: Bool
        var body: some View {
            HStack(spacing: 2) {
                Text(column.title).font(R95.ui(12, bold: true)).foregroundStyle(R95.black)
                    .lineLimit(1)
                if let ascending = column.sortAscending {
                    PixelIcon(art: ascending ? .triangleUp : .triangleDown, size: 16)
                        .accessibilityLabel(ascending ? Text("오름차순") : Text("내림차순"))
                }
            }
            .padding(.horizontal, 6)
            .offset(x: isPressed ? 1 : 0, y: isPressed ? 1 : 0)
            .frame(width: column.width, height: R95.tableHeaderHeight, alignment: column.alignment)
            .frame(maxWidth: column.width == nil ? .infinity : nil, alignment: column.alignment)
            .background(R95.gray)
            .retroBevel(isPressed ? .pressed : .raised)
        }
    }
}

/// 열 경계 손잡이.
///
/// 손잡이가 경계를 따라 움직이므로 자기 좌표로 재면 끄는 동안 기준이 흔들린다.
/// 전역 좌표로 재고, 직전보다 바뀐 만큼만 넘긴다.
private struct ColumnResizeHandle: View {
    let onDrag: @MainActor (CGFloat) -> Void
    @State private var last: CGFloat = 0

    var body: some View {
        Color.clear
            .frame(width: 8)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        onDrag(value.translation.width - last)
                        last = value.translation.width
                    }
                    .onEnded { _ in last = 0 }
            )
            .accessibilityHidden(true)
    }
}

struct Retro95Separator: View {
    @Environment(\.displayScale) private var displayScale
    var body: some View {
        VStack(spacing: 0) {
            R95.shadow.frame(height: 1)
            R95.white.frame(height: 1)
        }.accessibilityHidden(true)
    }
}

/// 한국어 상태를 유지하면서 안전도 칩과 같은 팔레트로 의미를 구분한다.
struct Retro95StatusChip: View {
    let title: String
    let icon: PixelArt
    let level: SafetyLevel

    var body: some View {
        HStack(spacing: 2) {
            PixelIcon(art: icon, size: 16)
            Text(title).font(R95.ui(10, bold: true))
        }
        .padding(.horizontal, 4)
        .frame(height: 20)
        .foregroundStyle(level == .caution ? R95.black : R95.white)
        .background(level == .safe ? R95.safe : level == .caution ? R95.review : R95.danger)
        .retroBevel(.field)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
