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

    var body: some View {
        HStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 결과 목록일 때만 독이 붙는다. 시작·검색 중에는 고를 것이 없고,
            // 완료 화면에서는 같은 항목을 다시 정리할 수 있게 되므로 내린다.
            if showsDock {
                Divider()
                SelectionDock(model: model) { showsConfirm = true }
                    .sidebarMaterial()
            }
        }
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
            RingGauge(percent: total > 0 ? done * 100 / total : 0, caption: "정리하는 중")
        case .cleaned:
            cleanDone
        }
    }

    /// 시작 화면. 무엇을 하는 화면인지 먼저 말하고 버튼 하나만 준다.
    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: feature.systemImageName)
                .font(.system(size: Theme.Icon.large))
                .foregroundStyle(Theme.accentText)

            Text(feature.displayName)
                .font(Theme.title)

            Text(feature.summary)
                .font(Theme.bodyText)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            Button("검색") { Task { await model.scan() } }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
        }
    }

    private func scanning(percent: Int, remaining: Int?) -> some View {
        VStack(spacing: 14) {
            RingGauge(percent: percent, caption: "훑는 중")

            if let remaining {
                Text("약 \(ProgressDisplay.readable(seconds: remaining)) 남음")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // 다 끝나기 전에도 성과가 보여야 기다릴 만하다
            if !model.items.isEmpty {
                Text("\(model.items.count)개 · \(model.formattedTotalSize) 발견")
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var emptyResult: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: Theme.Icon.large))
                .foregroundStyle(.secondary)
            Text("정리할 항목이 없음").font(Theme.title)
            Text("회수할 만한 크기의 항목을 찾지 못했습니다.")
                .font(Theme.bodyText)
                .foregroundStyle(.secondary)
            Button("다시 검색") { Task { await model.scan() } }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)
        }
    }

    /// 정리 완료. 목록으로 바로 돌아가면 얼마를 비웠는지 볼 틈이 없다.
    @ViewBuilder
    private var cleanDone: some View {
        if let report = model.report {
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: Theme.Icon.large))
                    .foregroundStyle(Theme.accentText)

                Text("\(report.formattedReclaimed)의 파일이 삭제됨")
                    .font(Theme.title)
                    .monospacedDigit()

                // 실패 사유는 길어서 한 줄에 안 들어간다. 개수만 보이고 전체는 툴팁에.
                if !report.failed.isEmpty {
                    Text("\(report.failed.count)개는 옮기지 못했습니다")
                        .font(Theme.bodyText)
                        .foregroundStyle(.red)
                        .help(report.failed.compactMap(\.failureReason).joined(separator: "\n"))
                }

                Button("완료") { model.dismissReport() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - 결과 목록

    /// 기능 화면은 **판단 기준**으로 묶는다. 스마트 스캔만 카테고리로 나눈다 —
    /// 거기서는 어느 기능이 얼마를 찾았는지가 정보다.
    private var groups: [ScanGroup] {
        feature == .smartScan ? model.groups : model.safetyGroups
    }

    private var resultList: some View {
        VStack(spacing: 0) {
            // 이 화면이 무엇을 보여주는지 한 문장. 목록만 던지면
            // 무엇을 기준으로 고르라는 것인지가 없다.
            Text(feature.reviewHint)
                .font(Theme.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)

            Divider().overlay(Theme.border)

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
                            ItemRow(item: item, isOn: binding(for: item))
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    } header: {
                        sectionHeader(group)
                    }
                }
            }
            .listStyle(.plain)
            // 아래에 섹션이 더 있다는 유일한 단서
            .scrollIndicators(.visible)
            .background(FrameProbeAnchor())   // ← 측정용. 걷어낸다.
        }
    }

    private func sectionHeader(_ group: ScanGroup) -> some View {
        HStack(spacing: 8) {
            // 접힘 표시는 caret 하나로 충분하다. 헤더 어디를 눌러도 접힌다.
            Image(systemName: model.isCollapsed(group) ? "chevron.right" : "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 10)

            // SwiftUI Toggle은 부분 선택을 표현하지 못해 버튼으로 그린다
            Button { model.toggleAll(in: group) } label: {
                let state = model.selectionState(of: group)
                Image(systemName: state.symbolName)
                    .foregroundStyle(state.isEmphasized ? Theme.accentText : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("이 묶음 전체 선택 / 해제")

            // 묶음 이름은 본문보다 작게. 헤더가 행보다 커 보이면 목록이 헤더에 눌린다.
            Text(group.displayName)
                .font(Theme.caption.weight(.semibold))
                .kerning(0.4)
                .foregroundStyle(Theme.textSecondary)
            Text("\(group.items.count)")
                .font(Theme.captionMono)
                .foregroundStyle(Theme.textTertiary)

            Spacer()

            Text(group.formattedTotalSize)
                .font(Theme.captionMono)
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 24)
        .frame(height: Theme.sectionHeaderHeight)
        .frame(maxWidth: .infinity)
        .background(Theme.surfaceSunken)
        .contentShape(Rectangle())
        .onTapGesture { model.toggleCollapsed(group) }
    }

    // 하단 액션 바는 `SelectionDock`이 대신한다.
    //
    // 바는 가로로 길어서 "얼마를 골랐나"(요약)와 "무엇을 할 수 있나"(버튼)가
    // 한 줄에 눌려 들어갔다. 세로 독은 그 둘을 위아래로 벌려 놓는다.
    // `선택` 프리셋과 `다시 검색`은 툴바로 올라간다(핸드오프 1절).

    // MARK: - 거들기

    /// `selection`(Set<URL>)을 체크박스가 쓰는 Bool 바인딩으로 잇는다.
    private func binding(for item: CleanupItem) -> Binding<Bool> {
        Binding(
            get: { model.isSelected(item) },
            set: { model.setSelection($0, for: item) })
    }
}
