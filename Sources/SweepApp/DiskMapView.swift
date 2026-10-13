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

    /// 탐색 상태와 별개로 행 강조만 보관해 모델의 선택 동작을 바꾸지 않는다.
    @State private var focusedNode: URL?
    @State private var hoveredNode: URL?

    /// 가지치기로 자식이 없는 폴더도 실제 속성으로 구분한다.
    @State private var directoryFlags: [URL: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            header
            Retro95Separator()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(R95.gray)
        .foregroundStyle(R95.black)
        .onChange(of: model.tiles, initial: true) { _, nodes in
            directoryFlags = Dictionary(uniqueKeysWithValues: nodes.map { node in
                let values = try? node.url.resourceValues(forKeys: [.isDirectoryKey])
                return (node.url, values?.isDirectory ?? node.url.hasDirectoryPath)
            })
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
            Menu {
                Button("선택하세요") { model.selectedRoot = nil }
                // 그룹으로 나눈다. 열 몇 개를 한 줄로 늘어놓으면 고르기 어렵다.
                ForEach(DiskMapRoot.Group.allCases, id: \.self) { group in
                    let roots = model.availableRoots.filter { $0.group == group }
                    if !roots.isEmpty {
                        Section(group.rawValue) {
                            ForEach(roots) { root in
                                Button(root.label) { model.selectedRoot = root.url }
                            }
                        }
                    }
                }
            } label: {
                Text(model.availableRoots.first(where: { $0.url == model.selectedRoot })?.label
                     ?? "선택하세요")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(R95.ui())
                    .foregroundStyle(R95.black)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            // 베벨은 메뉴 **바깥**에 그린다. borderless 메뉴는 라벨의 배경·Canvas를
            // 버리고 글자만 남겨서, 라벨 안에 그린 상자가 화면에 나오지 않았다.
            .padding(.leading, 8)
            .padding(.trailing, 24)
            .frame(width: DiskMapColumns.location, height: R95.buttonHeight, alignment: .leading)
            .background(R95.gray)
            .retroRaised()
            .overlay(alignment: .trailing) {
                PixelIcon(art: .triangleDown, size: 16)
                    .padding(.trailing, 4)
                    .allowsHitTesting(false)
            }
            .accessibilityLabel("시작 지점")
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
                Button { model.goUp() } label: {
                    HStack { PixelIcon(art: .arrowUp, size: 16); Text("위로") }
                }
                .help("위로")
            }

            // 앱 밖에서 지우거나 내려받아도 이 화면은 모른다. 다시 읽는 입구가 필요하다.
            // 아직 아무것도 안 읽었거나 읽는 중이면 누를 것이 없다.
            Button {
                Task { await model.reload() }
            } label: {
                PixelIcon(art: .refresh, size: 16)
            }
            .help("다시 읽기")
            .accessibilityLabel("다시 읽기")
            .disabled(model.selectedRoot == nil || model.isScanning)
        }
        .padding(8)
        .buttonStyle(Retro95ButtonStyle())
        .background(R95.gray)
        .retroRaised()
    }

    private var breadcrumb: some View {
        HStack(spacing: 4) {
            ForEach(Array(model.path.enumerated()), id: \.element.id) { index, node in
                if index > 0 { PixelIcon(art: .triangleRight, size: 16) }
                Button(node.name.isEmpty ? "/" : node.name) { model.jump(to: index) }
                    .buttonStyle(Retro95ButtonStyle())
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
                    Retro95ScanPanel(title: "재는 중", headline: "\(scanned.formatted())개 세는 중…",
                                     detail: nil, fraction: nil, percentText: nil,
                                     leftFooter: nil, rightFooter: nil)
                case .measuring(let percent):
                    Retro95ScanPanel(title: "재는 중", headline: "사용량을 재는 중…",
                                     detail: nil, fraction: Double(percent) / 100,
                                     percentText: "\(percent)%", leftFooter: nil, rightFooter: nil)
                }
                // 볼륨 전체는 몇 분이 걸린다. 못 멈추면 못 쓴다.
                Button("중단") { model.cancelLoad() }
                    .buttonStyle(Retro95ButtonStyle())
            }
            .padding(12)
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
            Retro95Dialog(title: "훑기를 멈췄습니다", icon: .pieChart) {
                Text("다시 훑으면 이어서가 아니라 처음부터 셉니다.")
            } buttons: {
                Button("다시 훑기") { Task { await model.reload() } }
                    .buttonStyle(Retro95ButtonStyle(isDefault: true))
            }
            .frame(maxWidth: R95.dialogWidth)
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
            Retro95GroupBox(title: "디스크 사용량") {
                VStack(spacing: 0) {
                    Retro95TableHeader(columns: DiskMapColumns.headers)
                    List(model.tiles) { node in
                        row(node, largest: model.tiles.first?.size ?? 0)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(R95.white)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.visible)
                }
                .background(R95.white)
                .retroSunken()
            }

            blockedFooter

            // 전체 디스크 접근은 **한 번 켜면 끝나는 스위치**다. 앱 폴더마다 따로 묻는
            // "다른 앱의 데이터" 물음을 통째로 없앤다 — 늘 보이는 자리에 둔다.
            if FullDiskAccessBanner.isNeeded {
                Retro95Separator()
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
            Retro95Separator()

            HStack(spacing: 12) {
                Text("권한이 막혀 못 읽는 폴더가 있어요")
                    .font(Theme.caption)
                    .foregroundStyle(SafetyLevel.caution.tint)
                Spacer(minLength: 12)
                Button("시스템 설정 열기") { PrivacySettings.openFilesAndFolders() }
                    .buttonStyle(Retro95ButtonStyle())
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

        let isFocused = focusedNode == node.id
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                PixelIcon(art: isFolder(node) ? .folder : .documents, size: 16)
                Text(node.name)
                    .font(R95.ui(12, bold: true))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 6)
            .frame(width: DiskMapColumns.name, alignment: .leading)

            // 못 읽은 폴더는 크기를 지어내지 않는다. 0 KB라고 쓰면 거짓말이다.
            Text(node.isReadable ? node.formattedSize : "권한 없음")
                .font(R95.mono(11))
                .padding(.horizontal, 6)
                .frame(width: DiskMapColumns.size, alignment: .trailing)

            // 아주 작아도 블록 하나를 남겨 항목의 존재를 알린다.
            Retro95ProgressBar(fraction: ratio)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)

            HStack(spacing: DiskMapColumns.actionSpacing) {
                statusBadge(node, veto: veto)
                    .frame(width: DiskMapColumns.status)
                Group {
                    if !node.isReadable {
                        Button("열기…") { unblock(node) }
                            .buttonStyle(Retro95ButtonStyle())
                    } else {
                        Color.clear.frame(height: R95.buttonHeight)
                    }
                }
                .frame(width: DiskMapColumns.open)
                iconButton(.folder, "Finder에서 보기") { ItemActions.reveal(node.url) }
                iconButton(.documents, "경로 복사") { ItemActions.copyPath(node.url) }
                // 왜 못 지우는지는 눌러 보고 알 일이 아니다. 사유를 미리 붙인다.
                iconButton(.trash, veto?.message ?? "휴지통으로 이동") {
                    pendingDelete = node
                }
                .disabled(veto != nil)
                PixelIcon(art: .triangleRight, size: 16)
                    .opacity(isDrillable ? 1 : 0)
                    .frame(width: DiskMapColumns.disclosure)
            }
            .frame(width: DiskMapColumns.actions, alignment: .leading)
        }
        .frame(minHeight: R95.tableRowHeight)
        .foregroundStyle(isFocused ? R95.white : R95.black)
        .background(isFocused ? R95.navy : hoveredNode == node.id ? R95.light : R95.white)
        .contentShape(Rectangle())
        .onHover { hoveredNode = $0 ? node.id : nil }
        .onTapGesture {
            focusedNode = node.id
            model.drillDown(into: node)
        }
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

    /// 하위 항목이 있거나 못 읽는 것은 트리가 이미 폴더로 알고 있다.
    /// 디스크를 다시 묻는 것은 빈 폴더처럼 트리만으로 모를 때뿐이다.
    private func isFolder(_ node: DiskUsageNode) -> Bool {
        !node.children.isEmpty || !node.isReadable || directoryFlags[node.url] == true
    }

    /// 못 읽는 상태를 먼저 표시해 보호 여부만 보고 정리 가능으로 오해하지 않게 한다.
    @ViewBuilder
    private func statusBadge(_ node: DiskUsageNode, veto: RemovalVeto?) -> some View {
        if !node.isReadable {
            Retro95StatusChip(title: "권한 없음", icon: .warning, level: .caution)
                .help("권한이 막혀 안을 볼 수 없습니다")
        } else if let veto {
            Retro95StatusChip(title: "보호됨", icon: .lock, level: .danger)
                .help(veto.message)
        } else {
            Retro95StatusChip(title: "정리 가능", icon: .check, level: .safe)
        }
    }

    /// 명시적 버튼 스타일로 목록의 행 탭과 액션을 따로 처리한다.
    private func iconButton(_ art: PixelArt, _ hint: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PixelIcon(art: art, size: 16)
        }
        .buttonStyle(Retro95ButtonStyle())
        .frame(width: DiskMapColumns.iconButton)
        .help(hint)
        .accessibilityLabel(hint)
    }

    private func placeholder(_ title: String, detail: String) -> some View {
        Retro95Dialog(title: title, icon: .pieChart) {
            Text(detail)
        } buttons: {}
        .frame(maxWidth: R95.dialogWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
