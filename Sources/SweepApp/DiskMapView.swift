import SwiftUI
import SweepKit

/// 디스크 사용량을 면적으로 보여준다. 읽기 전용 — 여기서는 아무것도 지우지 않는다.
struct DiskMapView: View {
    @State private var model = DiskMapModel()
    @State private var root: URL?
    @State private var hovered: URL?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            // 열자마자 뭔가 보여준다. 빈 화면에서 시작하면 뭘 해야 할지 모른다.
            guard root == nil, let first = model.availableRoots.first else { return }
            root = first
            await model.load(first)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Picker("시작 지점", selection: $root) {
                Text("선택하세요").tag(URL?.none)
                ForEach(model.availableRoots, id: \.self) { url in
                    Text(shortName(url)).tag(URL?.some(url))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 240)
            .onChange(of: root) { _, new in
                guard let new else { return }
                Task { await model.load(new) }
            }

            breadcrumb

            Spacer()

            if let current = model.current {
                Text(current.formattedSize)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if model.canGoUp {
                Button("위로") { model.goUp() }
            }
        }
        .padding(12)
    }

    private var breadcrumb: some View {
        HStack(spacing: 4) {
            ForEach(Array(model.path.enumerated()), id: \.element.id) { index, node in
                if index > 0 { Image(systemName: "chevron.right").font(.caption2) }
                Button(node.name.isEmpty ? "/" : node.name) { model.jump(to: index) }
                    .buttonStyle(.link)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var content: some View {
        if model.isScanning {
            VStack(spacing: 8) {
                ProgressView()
                Text("사용량을 재는 중…").foregroundStyle(.secondary)
            }
        } else if let current = model.current {
            if model.tiles.isEmpty {
                placeholder("\(current.name)에는 더 나눌 항목이 없습니다",
                            detail: current.formattedSize)
            } else {
                map
            }
        } else {
            placeholder("시작 지점을 고르세요",
                        detail: "정리 대상과 같은 범위만 살펴봅니다.")
        }
    }

    private var map: some View {
        GeometryReader { geometry in
            let tiles = Treemap.layout(model.tiles,
                                       in: CGRect(origin: .zero, size: geometry.size))
            ZStack(alignment: .topLeading) {
                ForEach(Array(tiles.enumerated()), id: \.element.node.id) { index, tile in
                    tileView(tile, hue: Treemap.hue(for: index))
                }
            }
        }
        .padding(8)
    }

    /// 타일 하나. 라벨 아래 남는 자리에 **자식을 한 겹 더** 깐다.
    ///
    /// 한 층만 그리면 5.76GB짜리 타일이 화면을 다 먹고 그 안이 비어 있어
    /// "크다"는 사실 외에 아무 정보도 주지 못한다.
    private func tileView(_ tile: TreemapTile, hue: Double) -> some View {
        let showsLabel = tile.rect.width > 52 && tile.rect.height > 26
        let labelHeight: CGFloat = showsLabel ? 32 : 0
        let inner = CGRect(x: 6, y: labelHeight + 4,
                           width: max(tile.rect.width - 12, 0),
                           height: max(tile.rect.height - labelHeight - 10, 0))
        let children = Treemap.fitsChildren(inner)
            ? Treemap.layout(tile.node.children, in: inner)
            : []
        let isHovered = hovered == tile.node.id

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hue: hue, saturation: 0.45, brightness: 0.55)
                    .opacity(isHovered ? 0.5 : 0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color(hue: hue, saturation: 0.5, brightness: 0.8),
                                      lineWidth: isHovered ? 2 : 1))

            if showsLabel {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tile.node.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text(tile.node.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(6)
            }

            // 자식 층. 클릭은 부모가 받아 드릴다운으로 이어진다.
            ForEach(children, id: \.node.id) { child in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hue: hue, saturation: 0.6, brightness: 0.9).opacity(0.30))
                    .overlay(RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.white.opacity(0.12)))
                    .frame(width: max(child.rect.width - 1, 1),
                           height: max(child.rect.height - 1, 1))
                    .offset(x: child.rect.minX, y: child.rect.minY)
                    .allowsHitTesting(false)
                    .help("\(child.node.name) · \(child.node.formattedSize)")
            }
        }
        .frame(width: max(tile.rect.width, 1), height: max(tile.rect.height, 1))
        .offset(x: tile.rect.minX, y: tile.rect.minY)
        .contentShape(Rectangle())
        .onHover { hovered = $0 ? tile.node.id : nil }
        .onTapGesture { model.drillDown(into: tile.node) }
        .help("\(tile.node.url.path) · \(tile.node.formattedSize)")
    }

    private func placeholder(_ title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 홈 아래 경로는 `~`로 줄여 Picker가 넘치지 않게 한다.
    private func shortName(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home)
            ? "~" + url.path.dropFirst(home.count)
            : url.path
    }
}
