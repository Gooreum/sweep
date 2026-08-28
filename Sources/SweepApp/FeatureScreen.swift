import SwiftUI
import SweepKit

/// 기능 하나의 화면. 시작 → 검색 → 결과 → 완료 네 단계를 오간다.
///
/// 단계는 `ScanModel.Phase`가 정한다. 뷰가 자기 상태를 따로 들면 어긋난다.
struct FeatureScreen: View {
    let feature: Feature
    @Bindable var model: ScanModel

    var body: some View {
        VStack(spacing: 0) {
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 결과 목록일 때만 하단 바가 있다. 시작·검색 중에는 고를 것이 없다.
            if case .results = model.phase, !model.items.isEmpty {
                Divider()
                actionBar
            }
        }
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
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent)

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
                Text("약 \(Self.readable(seconds: remaining)) 남음")
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
                .font(.system(size: 48))
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
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.accent)

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

    private var resultList: some View {
        List {
            ForEach(model.groups) { group in
                Section {
                    ForEach(group.items) { item in
                        ItemRow(item: item, isOn: binding(for: item))
                    }
                } header: {
                    sectionHeader(group)
                }
            }
        }
        // 아래에 섹션이 더 있다는 유일한 단서
        .scrollIndicators(.visible)
    }

    private func sectionHeader(_ group: ScanGroup) -> some View {
        HStack(spacing: 8) {
            // SwiftUI Toggle은 부분 선택을 표현하지 못해 버튼으로 그린다
            Button { model.toggleAll(in: group) } label: {
                let state = model.selectionState(of: group)
                Image(systemName: state.symbolName)
                    .foregroundStyle(state.isEmphasized ? Theme.accent : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("이 묶음 전체 선택 / 해제")

            Label(group.category.displayName, systemImage: group.category.systemImageName)
            Text("\(group.items.count)")
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            Spacer()

            Text(group.formattedTotalSize)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 하단 바

    private var actionBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                // 얻을 수 있는 양이 먼저다. 선택량만 보이면 6.9GB를 찾아놓고
                // 111KB만 보이는 상태가 된다.
                Text("총계 \(model.formattedTotalSize)")
                    .font(Theme.bodyText.weight(.medium))
                    .monospacedDigit()
                Text("선택됨 \(model.selectedItems.count)/\(model.items.count) · "
                     + model.formattedSelectedSize)
                    .font(Theme.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Menu("선택") {
                ForEach(ScanModel.SelectionPreset.allCases, id: \.self) { preset in
                    Button(preset.rawValue) { model.apply(preset) }
                }
            }
            .frame(width: 88)

            Button("다시 검색") { Task { await model.scan() } }

            Button("정리") { Task { await model.removeSelected() } }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!model.hasSelection)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - 거들기

    /// "45초" / "1분 20초". 분을 넘겨도 초만 보여주면 읽기 나쁘다.
    static func readable(seconds: Int) -> String {
        seconds < 60 ? "\(seconds)초" : "\(seconds / 60)분 \(seconds % 60)초"
    }

    /// `selection`(Set<URL>)을 체크박스가 쓰는 Bool 바인딩으로 잇는다.
    private func binding(for item: CleanupItem) -> Binding<Bool> {
        Binding(
            get: { model.isSelected(item) },
            set: { model.setSelection($0, for: item) })
    }
}
