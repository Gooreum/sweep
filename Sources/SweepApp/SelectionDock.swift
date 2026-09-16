import SwiftUI
import SweepKit

/// 검토 목록 우측에 붙는 선택 요약 패널.
///
/// 하단 액션 바를 대신한다. 바는 가로로 길어서 "얼마를 골랐나"와 "무엇을 고를 수 있나"가
/// 한 줄에 눌려 들어갔다. 세로 패널은 그 둘을 위아래로 벌려 놓을 수 있다.
///
/// **완료 화면에서는 내린다** — 같은 항목을 다시 정리할 수 있게 되므로.
struct SelectionDock: View {
    @Bindable var model: ScanModel

    /// 주 동작. 목록에서 바로 지우지 않고 확인 시트를 거친다.
    let onClean: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("선택")
                .font(Theme.caption)
                .foregroundStyle(Theme.textTertiary)

            Text(model.formattedSelectedSize)
                .font(.system(size: 30, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 6)

            Text("\(model.selectedItems.count)개 · 전체 \(model.items.count)개 중")
                .font(Theme.captionMono)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(SafetyLevel.allCases, id: \.self) { level in
                    distributionRow(level)
                }
            }
            .padding(.top, 24)

            Spacer(minLength: 16)

            // 되돌릴 수 있다는 것을 버튼 **앞에** 말한다. 누른 뒤에 알려주면 늦다.
            Text("휴지통으로 옮기며 30일간 되돌릴 수 있습니다.")
                .font(Theme.caption)
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)

            // 레이블에 폭을 준다. 버튼 바깥에 주면 스타일의 padding이 먼저 잡혀
            // 내용 크기로 줄어든 뒤 오른쪽으로 치우친다 — 실측으로 그렇게 나왔다.
            Button { onClean() } label: {
                Text(model.hasSelection
                     ? "\(model.formattedSelectedSize) 정리" : "선택한 항목 없음")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!model.hasSelection)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(width: Theme.dockWidth, alignment: .leading)
    }

    /// 안전도별 개수. 무엇을 담았는지보다 **무엇이 남았는지**가 여기서 읽힌다.
    private func distributionRow(_ level: SafetyLevel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: level.symbolName)
                .font(.system(size: Theme.safetyIconSlot))
                .foregroundStyle(level.tint)
                .frame(width: Theme.safetyIconSlot + 4)

            Text(level.dockLabel)
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)

            Spacer(minLength: 8)

            Text("\(model.items.filter { $0.safety == level }.count)개")
                .font(Theme.captionMono)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(height: 22)
    }
}

extension SafetyLevel {

    /// 독에 쓰는 이름. 등급 이름("안전")이 아니라 **무엇을 뜻하는지**를 적는다 —
    /// "안전 4개"보다 "다시 만들 수 있음 4개"가 고를 때 쓸모 있다.
    var dockLabel: String {
        switch self {
        case .safe: "다시 만들 수 있음"
        case .caution: "확인 필요"
        case .danger: "보호됨 · 선택 불가"
        }
    }
}
