import SwiftUI
import SweepKit

/// 기능 하나의 화면. 시작 → 검색 → 결과 → 완료 네 단계를 오간다.
///
/// 단계는 `ScanModel.Phase`가 정한다. 뷰가 자기 상태를 따로 들면 어긋난다.
struct FeatureScreen: View {
    let feature: Feature
    @Bindable var model: ScanModel

    /// 확인 시트를 띄울지. 목록에서 바로 지우지 않는다 —
    /// 되돌릴 수 없는 항목이 몇 개 빠졌는지 한 번 더 보여줘야 한다.
    @State private var showsConfirm = false

    /// 옮기지 못한 항목 시트를 띄울지.
    @State private var showsFailures = false
    /// 휴지통을 열지 못했다(샌드박스가 막는 경우). 조용히 넘어가지 않고 대신 할 일을 말한다.
    @State private var trashOpenFailed = false
    /// 되돌리기 실패 목록 시트.
    @State private var showsRestoreFailures = false

    var body: some View {
        VStack(spacing: 8) {
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 결과 목록일 때만 독이 붙는다. 시작·검색 중에는 고를 것이 없고,
            // 완료 화면에서는 같은 항목을 다시 정리할 수 있게 되므로 내린다.
            if showsDock {
                SelectionDock(model: model) { showsConfirm = true }
            }
        }
        .background(R95.gray)
        .sheet(isPresented: $showsConfirm) {
            CleanupConfirmSheet(model: model) {
                showsConfirm = false
                Task { await model.removeSelected() }
            } onCancel: {
                showsConfirm = false
            }
        }
    }

    private var showsDock: Bool {
        if case .results = model.phase { return !model.items.isEmpty }
        return false
    }

    // MARK: - 단계

    @ViewBuilder
    private var stage: some View {
        switch model.phase {
        case .idle:
            welcome
        case let .scanning(percent, remaining):
            scanning(percent: percent, remaining: remaining)
        case .results:
            if model.items.isEmpty { emptyResult } else { resultList }
        case let .removing(done, total):
            removing(done: done, total: total)
        case .cleaned:
            cleanDone
        case let .restoring(done, total):
            restoring(done: done, total: total)
        case .restored:
            restoreDone
        }
    }

    /// 시작 화면. 무엇을 하는 화면인지 먼저 말하고 버튼 하나만 준다.
    private var welcome: some View {
        Retro95Dialog(title: feature.displayName, icon: feature.pixelArt) {
            Text(feature.summary)
        } buttons: {
            Button("검색") { Task { await model.scan() } }
                .buttonStyle(Retro95ButtonStyle(isDefault: true))
        }
        .frame(maxWidth: R95.dialogWidth)
    }

    private func scanning(percent: Int, remaining: Int?) -> some View {
        VStack(spacing: 0) {
            // 다 끝나기 전에도 성과가 보여야 기다릴 만하다
            Retro95ScanPanel(
                title: "검색 중",
                headline: "\(feature.displayName) 훑는 중…",
                detail: feature.summary,
                fraction: Double(percent) / 100,
                percentText: "\(percent)%",
                leftFooter: model.items.isEmpty ? nil : "\(model.items.count)개 · \(model.formattedTotalSize) 발견",
                rightFooter: remaining.map { "약 \(ProgressDisplay.readable(seconds: $0)) 남음" })
            Spacer()
        }
    }

    private func removing(done: Int, total: Int) -> some View {
        VStack(spacing: 0) {
            Retro95ScanPanel(
                title: "정리 중",
                headline: "휴지통으로 옮기는 중…",
                detail: nil,
                fraction: total > 0 ? Double(done) / Double(total) : nil,
                percentText: total > 0 ? "\(done * 100 / total)%" : nil,
                leftFooter: "\(done) / \(total)",
                rightFooter: nil)
            Spacer()
        }
    }

    private func restoring(done: Int, total: Int) -> some View {
        VStack(spacing: 0) {
            Retro95ScanPanel(
                title: "되돌리는 중",
                headline: "원래 자리로 되돌리는 중…",
                detail: nil,
                fraction: total > 0 ? Double(done) / Double(total) : nil,
                percentText: total > 0 ? "\(done * 100 / total)%" : nil,
                leftFooter: "\(done) / \(total)",
                rightFooter: nil)
            Spacer()
        }
    }

    /// 되돌리기 결과. 정리 완료 화면과 같은 규칙으로 성공·일부·전부 실패를 아이콘부터 나눈다.
    @ViewBuilder
    private var restoreDone: some View {
        if let report = model.restoreReport {
            let restored = report.succeeded.count
            let failed = report.failed.count
            let (title, icon): (String, PixelArt) =
                restored == 0 ? ("되돌리지 못했습니다", .warning)
                : failed > 0 ? ("일부만 되돌렸습니다", .warning)
                : ("되돌리기 완료", .check)
            Retro95Dialog(title: title, icon: icon) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(restored == 0
                         ? "\(failed)개를 되돌리지 못했습니다"
                         : "\(restored)개 · \(report.formattedReclaimed)를 원래 자리로 되돌렸습니다")
                        .font(R95.ui(13, bold: true))
                        .monospacedDigit()

                    if failed > 0 {
                        Button {
                            showsRestoreFailures = true
                        } label: {
                            HStack(alignment: .top, spacing: 6) {
                                PixelIcon(art: .warning, size: 16)
                                Text(restored == 0 ? "사유 자세히 보기"
                                     : "\(failed)개는 되돌리지 못했습니다 — 자세히 보기")
                                    .underline()
                            }
                            .foregroundStyle(R95.danger)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } buttons: {
                Button("완료") { model.dismissReport() }
                    .buttonStyle(Retro95ButtonStyle(isDefault: true))
            }
            .frame(maxWidth: R95.dialogWidth)
            .sheet(isPresented: $showsRestoreFailures) {
                RemovalFailuresSheet.restore(report.failed) { showsRestoreFailures = false }
            }
        }
    }

    private var emptyResult: some View {
        Retro95Dialog(title: "정리할 항목이 없음", icon: .check) {
            Text("회수할 만한 크기의 항목을 찾지 못했습니다.")
        } buttons: {
            Button("다시 검색") { Task { await model.scan() } }
                .buttonStyle(Retro95ButtonStyle(isDefault: true))
        }
        .frame(maxWidth: R95.dialogWidth)
    }

    /// 정리 완료. 목록으로 바로 돌아가면 얼마를 비웠는지 볼 틈이 없다.
    @ViewBuilder
    private var cleanDone: some View {
        if let report = model.report {
            // 하나도 못 옮겼는데 녹색 체크를 띄우면 성공으로 읽힌다. 결과에 따라 아이콘부터 다르게 한다.
            let moved = report.succeeded.count
            let failed = report.failed.count
            let (title, icon): (String, PixelArt) =
                moved == 0 ? ("정리하지 못했습니다", .warning)
                : failed > 0 ? ("일부만 정리했습니다", .warning)
                : ("정리 완료", .check)
            Retro95Dialog(title: title, icon: icon) {
                VStack(alignment: .leading, spacing: 10) {
                    // 지운 것이 아니라 휴지통으로 옮긴 것이다.
                    Text(moved == 0
                         ? "\(failed)개를 휴지통으로 옮기지 못했습니다"
                         : "\(moved)개 · \(report.formattedReclaimed)를 휴지통으로 옮겼습니다")
                        .font(R95.ui(13, bold: true))
                        .monospacedDigit()

                    // 옮겼을 뿐 공간은 아직이다. 이걸 안 말하면 디스크 게이지가 그대로라 앱을 의심한다.
                    if let notice = report.trashNotice {
                        Text(notice)
                            .font(R95.ui(12))
                            .foregroundStyle(R95.deep)
                            .monospacedDigit()
                    }

                    // 실패 사유는 길어서 한 줄에 안 들어간다. 예전에는 툴팁에 합쳐 넣었는데,
                    // 호버해야 보이고 어느 파일이 왜 실패했는지 구분되지 않았다.
                    // 누르면 항목별 사유와 다음 행동을 보여주는 시트를 연다.
                    if !report.failed.isEmpty {
                        Button {
                            showsFailures = true
                        } label: {
                            HStack(alignment: .top, spacing: 6) {
                                PixelIcon(art: .warning, size: 16)
                                // 전부 실패면 윗줄이 이미 개수를 말했다. 같은 말을 두 번 하지 않는다.
                                Text(moved == 0 ? "사유 자세히 보기"
                                     : "\(failed)개는 옮기지 못했습니다 — 자세히 보기")
                                    .underline()
                            }
                            .foregroundStyle(R95.danger)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } buttons: {
                // 휴지통 위치를 아는 것이 있을 때만. 확인을 묻지 않는다 — 지우지 않고 원래 자리로 옮기기만 한다.
                if model.canUndo {
                    Button("되돌리기") { Task { await model.undoLastCleanup() } }
                        .buttonStyle(Retro95ButtonStyle())
                }
                if moved > 0 {
                    // 열어 주기만 한다. 비우는 것은 영구 삭제라 사용자가 Finder에서 직접 한다.
                    Button("휴지통 열기") { trashOpenFailed = !ItemActions.openTrash() }
                        .buttonStyle(Retro95ButtonStyle())
                }
                Button("완료") { model.dismissReport() }
                    .buttonStyle(Retro95ButtonStyle(isDefault: true))
            }
            .frame(maxWidth: R95.dialogWidth)
            .alert("휴지통을 열지 못했습니다", isPresented: $trashOpenFailed) {
                Button("확인") {}
            } message: {
                Text("Dock의 휴지통을 열어 비워 주세요.")
            }
            .sheet(isPresented: $showsFailures) {
                RemovalFailuresSheet(failed: report.failed) {
                    showsFailures = false
                } onRetry: {
                    showsFailures = false
                    Task { await model.retryFailed() }
                }
            }
        }
    }

    // MARK: - 결과 목록

    /// 기능 화면은 **판단 기준**으로 묶는다. 스마트 스캔만 카테고리로 나눈다 —
    /// 거기서는 어느 기능이 얼마를 찾았는지가 정보다.
    private var groups: [ScanGroup] {
        feature == .smartScan ? model.groups : model.safetyGroups
    }

    /// 결과 전체에 날짜가 하나라도 있을 때만 날짜 열을 둔다. 헤더와 행이 같은 값을 쓴다.
    private var showsDates: Bool {
        model.items.contains { $0.datesLine() != nil }
    }

    private var resultList: some View {
        // 한 번만 센다. 행 클로저 안에서 프로퍼티를 읽으면 행마다 전체 항목을 다시 훑는다.
        let showsDates = showsDates
        return VStack(spacing: 0) {
            Retro95GroupBox(title: "정리 항목") {
                VStack(spacing: 6) {
                    Text(feature.reviewHint)
                        .font(R95.ui(12))
                        .foregroundStyle(R95.deep)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 0) {
                        Retro95TableHeader(columns: ItemTableColumns.headers(showsDates: showsDates))
                        List {
                            ForEach(groups) { group in
                                Section {
                                    // 접었으면 행을 그리지 않는다. 높이 0으로 숨기면
                                    // 스크롤 길이가 그대로라 접은 보람이 없다.
                                    //
                                    // **`if`로 감싸지 않는다.** 조건부 뷰는 목록의 구조 자체를
                                    // 흔들어 SwiftUI가 view list를 통째로 다시 만든다 —
                                    // 비어 있는 배열을 주면 구조는 그대로고 내용만 없다.
                                    //
                                    // 수식자도 행마다 붙이지 않는다. 63줄에 각각 붙이면
                                    // `ModifiedContent` 껍질이 63개 생기고, 갱신마다 그것을
                                    // 전부 다시 훑는다 — 실측에서 `ModifiedElements.makeElements`가
                                    // 메인 스레드 상위를 차지했다. `ForEach` 하나에 붙이면 한 겹이다.
                                    ForEach(model.visibleRows(of: group)) { item in
                                        ItemRow(item: item, isOn: binding(for: item), showsDates: showsDates)
                                    }
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(R95.white)
                                } header: {
                                    sectionHeader(group)
                                        .listRowInsets(EdgeInsets())
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(R95.white)
                        .environment(\.defaultMinListRowHeight, R95.tableRowHeight)
                        // 아래에 섹션이 더 있다는 유일한 단서
                        .scrollIndicators(.visible)
                    }
                    .background(R95.white)
                    .retroSunken()
                }
            }
        }
    }

    private func sectionHeader(_ group: ScanGroup) -> some View {
        HStack(spacing: 0) {
            PixelIcon(art: model.isCollapsed(group) ? .triangleRight : .triangleDown, size: 16)
                .frame(width: ItemTableColumns.icon)

            // 부분 선택을 네이티브 Toggle 없이 표현해 긴 목록의 생성 비용을 줄인다.
            Button { model.toggleAll(in: group) } label: {
                Retro95Checkbox(state: checkState(of: group))
                    .frame(width: ItemTableColumns.check, height: ItemTableColumns.sectionHeight)
            }
            .buttonStyle(.plain)
            .help("이 묶음 전체 선택 / 해제")

            Text(group.displayName)
                .font(R95.ui(12, bold: true))
                .padding(.trailing, 8)
            Text("\(group.items.count)개")
                .font(R95.ui(12))
                .foregroundStyle(R95.deep)

            Spacer()

            Text(group.formattedTotalSize)
                .font(R95.mono(12))
                .padding(.trailing, ItemTableColumns.padding)
        }
        .foregroundStyle(R95.black)
        .frame(height: ItemTableColumns.sectionHeight)
        .frame(maxWidth: .infinity)
        .background(R95.gray)
        .overlay(alignment: .bottom) {
            Canvas { context, size in
                var line = Path()
                line.move(to: CGPoint(x: 0, y: 0.5))
                line.addLine(to: CGPoint(x: size.width, y: 0.5))
                context.stroke(line, with: .color(R95.shadow),
                               style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
            .frame(height: 1)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.toggleCollapsed(group) }
    }

    /// 모델의 세 상태를 그림 체크박스에 그대로 옮겨 부분 선택을 잃지 않는다.
    private func checkState(of group: ScanGroup) -> Retro95CheckState {
        switch model.selectionState(of: group) {
        case .none: .off
        case .partial: .mixed
        case .all: .on
        }
    }

    // MARK: - 거들기

    /// `selection`(Set<URL>)을 체크박스가 쓰는 Bool 바인딩으로 잇는다.
    private func binding(for item: CleanupItem) -> Binding<Bool> {
        Binding(
            get: { model.isSelected(item) },
            set: { model.setSelection($0, for: item) })
    }
}
