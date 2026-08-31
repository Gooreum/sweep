import SwiftUI
import AppKit
import SweepKit

/// 디스크 사용량을 면적으로 보여주고, 거기서 바로 손을 쓸 수 있게 한다.
///
/// 크기만 보여주고 아무것도 못 하면 "용량이 어디 있는지"만 알려주고 끝난다.
/// Finder로 가기 · 경로 복사 · 휴지통 세 가지를 행에 붙인다.
struct DiskMapView: View {
    /// **소유하지 않는다.** `AppModel`이 들고 있는 것을 받아 쓴다 —
    /// `@State`로 들면 탭을 옮기는 순간 트리가 사라지고, 돌아올 때
    /// 10초짜리 순회를 다시 돈다.
    @Bindable var model: DiskMapModel

    /// 삭제 확인을 기다리는 항목. nil이면 대화가 닫혀 있다.
    @State private var pendingDelete: DiskUsageNode?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            // 열자마자 뭔가 보여준다. 빈 화면에서 시작하면 뭘 해야 할지 모른다.
            //
            // **이미 본 것이 있으면 그대로 둔다.** 탭을 옮겼다 돌아올 때마다
            // 10초짜리 순회를 다시 도는 것이 이 화면의 가장 큰 불만이었다.
            //
            // 여기서는 대입만 한다. 실제 로드는 `.onChange`가 맡는다 —
            // 두 곳에서 부르면 순회가 두 번 돈다.
            guard model.selectedRoot == nil, model.current == nil, !model.isScanning
            else { return }
            model.selectedRoot = DiskMapRoot.initial?.url
        }
        // 정리 화면과 달리 여기엔 안전도 배지도 기본 선택도 없다.
        // 무엇을 지우는지 경로와 크기로 다시 보여주고 확인을 받는다.
        .confirmationDialog(
            "휴지통으로 이동할까요?",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { node in
            Button("휴지통으로 이동", role: .destructive) {
                Task { await model.remove(node) }
            }
            Button("취소", role: .cancel) {}
        } message: { node in
            // 목록에서는 이름만 보인다. 크기와 전체 경로를 여기서 한 번 더 보여준다.
            //
            // 줄바꿈으로 나누면 **뒷줄이 렌더되지 않는다** — 실측에서 경로만
            // 보이고 크기가 통째로 사라졌다. 한 줄로 잇는다.
            // 크기가 앞이다. "지울까?"에 답하려면 그 숫자가 먼저 필요하다.
            Text("\(node.formattedSize) · \(node.url.path)")
        }
        .alert("옮기지 못했습니다",
               isPresented: Binding(get: { model.removalFailure != nil },
                                    set: { if !$0 { model.clearRemovalFailure() } })) {
            Button("확인") { model.clearRemovalFailure() }
        } message: {
            Text(model.removalFailure ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Picker("시작 지점", selection: $model.selectedRoot) {
                Text("선택하세요").tag(URL?.none)
                // 그룹으로 나눈다. 열 몇 개를 한 줄로 늘어놓으면 고르기 어렵다.
                ForEach(DiskMapRoot.Group.allCases, id: \.self) { group in
                    let roots = model.availableRoots.filter { $0.group == group }
                    if !roots.isEmpty {
                        Section(group.rawValue) {
                            ForEach(roots) { root in
                                Text(root.label).tag(URL?.some(root.url))
                            }
                        }
                    }
                }
            }
            .labelsHidden()
            .frame(maxWidth: 240)
            // 도는 중에 다른 곳을 고르면 순회 두 개가 동시에 돌아
            // 나중에 끝난 쪽이 앞선 결과를 덮는다.
            .disabled(model.isScanning)
            .onChange(of: model.selectedRoot) { _, new in
                guard let new else { return }
                Task { await model.load(new) }
            }

            breadcrumb

            Spacer()

            if let current = model.current {
                Text(current.formattedSize)
                    .font(Theme.bodyText.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if model.canGoUp {
                Button("위로") { model.goUp() }
            }

            // 앱 밖에서 지우거나 내려받아도 이 화면은 모른다. 다시 읽는 입구가 필요하다.
            // 아직 아무것도 안 읽었거나 읽는 중이면 누를 것이 없다.
            Button {
                Task { await model.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("다시 읽기")
            .disabled(model.current == nil || model.isScanning)
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
                        .font(Theme.bodyText.monospacedDigit())
                        .foregroundStyle(.secondary)
                case .measuring(let percent):
                    RingGauge(percent: percent, caption: "재는 중")
                    Text("사용량을 재는 중…")
                        .font(Theme.caption)
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
                .font(Theme.bodyText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 200, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.border)
                    Capsule()
                        .fill(Theme.accent.opacity(0.55))
                        // 아주 작아도 흔적은 남긴다. 0폭이면 있는지조차 모른다.
                        .frame(width: max(geometry.size.width * ratio, 2))
                }
            }
            .frame(height: 10)

            Text(node.formattedSize)
                .font(Theme.bodyText.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .trailing)

            // 더 들어갈 수 있는 항목만 화살표를 준다
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(isDrillable ? Color.secondary : Color.clear)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.drillDown(into: node) }
        .contextMenu {
            Button("Finder에서 보기") {
                NSWorkspace.shared.activateFileViewerSelecting([node.url])
            }
            Button("경로 복사") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.url.path, forType: .string)
            }
            Divider()
            // 바로 지우지 않는다. 확인 대화에서 경로와 크기를 다시 보여준다.
            Button("휴지통으로 이동", role: .destructive) { pendingDelete = node }
        }
        .help(node.url.path)
    }

    private func placeholder(_ title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: Theme.Icon.large))
                .foregroundStyle(.secondary)
            Text(title).font(Theme.title)
            Text(detail).font(Theme.bodyText).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
