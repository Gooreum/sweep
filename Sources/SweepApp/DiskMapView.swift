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
        if let phase = model.loadPhase {
            VStack(spacing: 12) {
                switch phase {
                case .counting(let scanned):
                    // 분모를 만드는 중이라 아직 퍼센트가 없다. 숫자를 지어내지 않는다.
                    ProgressView()
                    Text("\(scanned.formatted())개 세는 중…")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                case .measuring(let percent):
                    ProgressView(value: Double(percent), total: 100)
                        .frame(width: 220)
                    Text("\(percent)%")
                        .font(.title3.monospacedDigit())
                    Text("사용량을 재는 중…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let current = model.current {
            if model.tiles.isEmpty {
                placeholder("\(current.name)에는 더 나눌 항목이 없습니다",
                            detail: current.formattedSize)
            } else {
                usageList
            }
        } else {
            placeholder("시작 지점을 고르세요",
                        detail: "정리 대상과 같은 범위만 살펴봅니다.")
        }
    }

    /// 크기순 막대 목록. 트리맵은 이 데이터에 맞지 않았다 —
    /// 5.76GB짜리 하나가 나머지를 눌러 면적 비교가 성립하지 않는다.
    private var usageList: some View {
        List(model.tiles) { node in
            row(node, largest: model.tiles.first?.size ?? 0)
        }
        .listStyle(.inset)
        .scrollIndicators(.visible)
    }

    private func row(_ node: DiskUsageNode, largest: Int64) -> some View {
        let ratio = node.barRatio(largest: largest)
        let isDrillable = !node.children.isEmpty

        return HStack(spacing: 12) {
            Text(node.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 200, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule()
                        .fill(Color.accentColor.opacity(0.55))
                        // 아주 작아도 흔적은 남긴다. 0폭이면 있는지조차 모른다.
                        .frame(width: max(geometry.size.width * ratio, 2))
                }
            }
            .frame(height: 10)

            Text(node.formattedSize)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .trailing)

            // 더 들어갈 수 있는 항목만 화살표를 준다
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(isDrillable ? Color.secondary : Color.clear)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.drillDown(into: node) }
        .help(node.url.path)
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
