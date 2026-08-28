import SwiftUI
import SweepKit

/// 디스크 사용량을 면적으로 보여준다. 읽기 전용 — 여기서는 아무것도 지우지 않는다.
struct DiskMapView: View {
    @State private var model = DiskMapModel()
    @State private var root: URL?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(maxWidth: 260)
            .onChange(of: root) { _, new in
                guard let new else { return }
                Task { await model.load(new) }
            }

            breadcrumb

            Spacer()

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
            let tiles = Treemap.layout(
                model.tiles,
                in: CGRect(origin: .zero, size: geometry.size))

            ZStack(alignment: .topLeading) {
                ForEach(tiles, id: \.node.id) { tile in
                    tileView(tile, rank: tiles.firstIndex(of: tile) ?? 0, total: tiles.count)
                }
            }
        }
        .padding(8)
    }

    private func tileView(_ tile: TreemapTile, rank: Int, total: Int) -> some View {
        // 큰 것일수록 진하게. 순위로 색조를 나눠 면적과 색이 같은 방향을 가리키게 한다.
        let intensity = 1.0 - Double(rank) / Double(max(total, 1)) * 0.65

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.accentColor.opacity(0.25 * intensity + 0.12))
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.primary.opacity(0.12)))

            // 라벨이 타일보다 크면 글자만 삐져나와 지저분해진다
            if tile.rect.width > 60, tile.rect.height > 30 {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tile.node.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text(tile.node.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(5)
            }
        }
        .frame(width: max(tile.rect.width, 1), height: max(tile.rect.height, 1))
        .offset(x: tile.rect.minX, y: tile.rect.minY)
        .contentShape(Rectangle())
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
