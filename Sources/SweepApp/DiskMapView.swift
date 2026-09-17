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

    /// 막힌 폴더를 그 자리에서 허락받으려면 필요하다.
    @Bindable var app: AppModel

    /// 삭제 확인을 기다리는 항목. nil이면 대화가 닫혀 있다.
    @State private var pendingDelete: DiskUsageNode?

    /// 허락에 실패한 사유. 성공했으면 nil.
    @State private var grantFailure: String?

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
        .alert("다른 폴더를 골랐습니다",
               isPresented: Binding(get: { grantFailure != nil },
                                    set: { if !$0 { grantFailure = nil } })) {
            Button("확인") { grantFailure = nil }
        } message: {
            Text(grantFailure ?? "")
        }
        // 허락이 늘거나 줄면 보던 자리를 **제자리에서** 다시 읽는다.
        //
        // 이 한 줄이 두 경우를 함께 처리한다 — 이 화면에서 허락한 경우와
        // 다른 화면(스마트 스캔·허락 화면)에서 허락한 경우.
        .onChange(of: app.grantedFolderCount) {
            Task { await model.reload() }
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
            .disabled(model.selectedRoot == nil || model.isScanning)
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

                // 볼륨 전체는 몇 분이 걸린다. 못 멈추면 못 쓴다.
                Button("중단") { model.cancelLoad() }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let current = model.current {
            if model.tiles.isEmpty {
                placeholder("\(current.name)에는 더 나눌 항목이 없습니다",
                            detail: current.formattedSize)
            } else {
                usageList
            }
        } else if model.selectedRoot != nil {
            // 중단했거나 아직 못 읽은 상태. 고른 곳은 있으니 다시 훑을 길을 준다.
            VStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: Theme.Icon.large))
                    .foregroundStyle(.secondary)
                Text("훑기를 멈췄습니다").font(Theme.title)
                Text("다시 훑으면 이어서가 아니라 처음부터 셉니다.")
                    .font(Theme.bodyText)
                    .foregroundStyle(.secondary)
                Button("다시 훑기") { Task { await model.reload() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            placeholder("시작 지점을 고르세요",
                        detail: "홈·볼륨 전체·응용 프로그램까지 살펴봅니다.")
        }
    }

    /// 크기순 막대 목록. 트리맵은 이 데이터에 맞지 않았다 —
    /// 5.76GB짜리 하나가 나머지를 눌러 면적 비교가 성립하지 않는다.
    private var usageList: some View {
        VStack(spacing: 0) {
            List(model.tiles) { node in
                row(node, largest: model.tiles.first?.size ?? 0)
            }
            .listStyle(.inset)
            .scrollIndicators(.visible)

            blockedFooter

            // 전체 디스크 접근은 **한 번 켜면 끝나는 스위치**다. 앱 폴더마다 따로 묻는
            // "다른 앱의 데이터" 물음을 통째로 없앤다 — 늘 보이는 자리에 둔다.
            if FullDiskAccessBanner.isNeeded {
                Divider().overlay(Theme.border)
                FullDiskAccessBanner()
            }
        }
    }

    /// 보이는 것 중 못 읽는 것이 하나라도 있으면 나온다.
    ///
    /// 열기 대화상자로 고르면 대개 풀리지만, TCC가 이미 거부를 기록했다면
    /// 시스템 설정에서 되돌리는 것이 확실한 길이다. 둘 다 준다 —
    /// 스마트 스캔의 같은 이름 장치와 문구·동작을 맞춘다.
    @ViewBuilder
    private var blockedFooter: some View {
        if model.tiles.contains(where: { !$0.isReadable }) {
            Divider().overlay(Theme.border)

            HStack(spacing: 12) {
                Text("권한이 막혀 못 읽는 폴더가 있어요")
                    .font(Theme.caption)
                    .foregroundStyle(SafetyLevel.caution.tint)
                Spacer(minLength: 12)
                Button("시스템 설정 열기") { PrivacySettings.openFilesAndFolders() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    /// 막힌 폴더를 열기 대화상자로 직접 고르게 한다.
    ///
    /// TCC 거부는 "앱이 알아서 여는 것"을 막는 것이라, 사용자가 명시적으로 고른
    /// 폴더는 접근이 따로 부여된다. `SmartScanView.unblock`과 **같은 길**을 쓴다 —
    /// 두 벌로 두면 언젠가 갈라진다.
    ///
    /// 다시 읽는 것은 여기서 하지 않는다. 허락이 늘면 `grantedFolderCount`가 바뀌고
    /// `onChange`가 받아 제자리에서 다시 읽는다.
    private func unblock(_ node: DiskUsageNode) {
        let grantable = FolderAccess.Grantable(folder: node.url,
                                               label: node.name,
                                               purpose: "용량 확인")
        guard let picked = FolderPicker.ask(for: grantable) else { return }
        do {
            try app.grantFolderAccess(picked, as: grantable)
        } catch let failure as FolderAccess.Failure {
            grantFailure = failure.message
        } catch {
            grantFailure = error.localizedDescription
        }
    }

    private func row(_ node: DiskUsageNode, largest: Int64) -> some View {
        let ratio = node.barRatio(largest: largest)
        let isDrillable = !node.children.isEmpty
        let veto = model.veto(for: node)

        return HStack(spacing: 12) {
            Text(node.name)
                .font(Theme.bodyText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 200, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 알약이 아니라 막대다. 창 안의 다른 막대와 radius를 맞춘다.
                    RoundedRectangle(cornerRadius: 3).fill(Theme.border)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.accent.opacity(0.55))
                        // 아주 작아도 흔적은 남긴다. 0폭이면 있는지조차 모른다.
                        .frame(width: max(geometry.size.width * ratio, 2))
                }
            }
            .frame(height: 6)

            // 못 읽은 폴더는 크기를 지어내지 않는다. 0 KB라고 쓰면 거짓말이다.
            //
            // 무채색으로 두면 "작아서 안 보이는 것"과 구분되지 않는다. 경고색을 준다.
            Text(node.isReadable ? node.formattedSize : "권한 없음")
                .font(node.isReadable ? Theme.bodyText.monospacedDigit() : Theme.caption)
                .foregroundStyle(node.isReadable
                                 ? Color.secondary : SafetyLevel.caution.tint)
                .frame(width: 84, alignment: .trailing)

            statusBadge(node, veto: veto)
                .frame(width: 78, alignment: .leading)

            // 우클릭해야 나오는 기능은 없는 기능이나 마찬가지다. 행에 그대로 둔다.
            HStack(spacing: 2) {
                // 못 읽는 줄에는 지우기보다 **여는 것**이 먼저다.
                // 알려만 주고 길을 주지 않으면 사용자가 할 수 있는 게 없다.
                if !node.isReadable {
                    Button("열기…") { unblock(node) }
                        .font(Theme.caption)
                }
                iconButton("folder", "Finder에서 보기") { ItemActions.reveal(node.url) }
                iconButton("doc.on.doc", "경로 복사") { ItemActions.copyPath(node.url) }
                // 왜 못 지우는지는 눌러 보고 알 일이 아니다. 사유를 미리 붙인다.
                iconButton("trash", veto?.message ?? "휴지통으로 이동") {
                    pendingDelete = node
                }
                .disabled(veto != nil)
            }

            // 더 들어갈 수 있는 항목만 화살표를 준다
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(isDrillable ? Color.secondary : Color.clear)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.drillDown(into: node) }
        .contextMenu {
            Button("Finder에서 보기") { ItemActions.reveal(node.url) }
            Button("경로 복사") { ItemActions.copyPath(node.url) }
            Divider()
            // 바로 지우지 않는다. 확인 대화에서 경로와 크기를 다시 보여준다.
            //
            // 옆의 휴지통 아이콘과 **같은 조건**으로 잠근다. 예전엔 메뉴에만 검사가
            // 없어서, 아이콘은 비활성인데 메뉴에서는 눌리고 조용히 실패했다.
            Button("휴지통으로 이동", role: .destructive) { pendingDelete = node }
                .disabled(veto != nil)
        }
        .help(node.url.path)
    }

    /// 지울 수 있는지를 **행에서 바로** 알린다.
    ///
    /// 새 색을 만들지 않는다 — 이 프로젝트의 색은 전부 대비를 실측해 고른 것이라
    /// 여기서 임의로 더하면 그 규칙이 깨진다. 초록은 디스크 맵 고유색을 쓰고,
    /// 보호됨은 색 대신 자물쇠 기호로 구분한다.
    ///
    /// **못 읽는 것이 먼저다.** 예전엔 `veto`만 봐서, 권한이 막혀 안을 볼 수도 없는
    /// 폴더가 "정리 가능 ✓"으로 떴다.
    @ViewBuilder
    private func statusBadge(_ node: DiskUsageNode, veto: RemovalVeto?) -> some View {
        if !node.isReadable {
            Label("권한 없음", systemImage: "exclamationmark.triangle.fill")
                .font(Theme.caption)
                .foregroundStyle(SafetyLevel.caution.tint)
                .help("권한이 막혀 안을 볼 수 없습니다")
        } else if let veto {
            Label("보호됨", systemImage: "lock.fill")
                .font(Theme.caption)
                .foregroundStyle(Theme.textTertiary)
                .help(veto.message)
        } else {
            Label("정리 가능", systemImage: "checkmark")
                .font(Theme.caption)
                .foregroundStyle(Theme.tint(.diskMap))
        }
    }

    /// 행 안의 작은 액션 버튼. `.plain`이라야 행 전체 탭 제스처와 다투지 않는다.
    private func iconButton(_ symbol: String, _ hint: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: Theme.Icon.small))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(hint)
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
