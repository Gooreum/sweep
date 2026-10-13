import SwiftUI
import SweepKit

/// 결과 아래에 선택량과 동작을 나란히 두어 확인 시트 전에 판단할 수 있게 한다.
struct SelectionDock: View {
    @Bindable var model: ScanModel

    /// 주 동작은 확인 시트를 열어 목록에서 바로 지우지 않게 한다.
    let onClean: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PixelIcon(art: .computerLarge, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text("선택: \(model.selectedItems.count)개 · 전체 \(model.items.count)개 중")
                    .font(R95.ui(12))
                Text("선택 크기: \(model.formattedSelectedSize)")
                    .font(R95.ui(20, bold: true))
                    .monospacedDigit()
                    .lineLimit(1)
                    // 이 줄이 독의 요점이라 말줄임 대신 글자를 줄인다.
                    // fixedSize로 고정하면 독이 창보다 넓어져 화면 전체가 잘렸다.
                    .minimumScaleFactor(0.7)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ForEach(SafetyLevel.allCases, id: \.self) { level in
                        distributionRow(level)
                    }
                }
                // 되돌릴 수 있다는 것을 버튼 앞에 말한다. 누른 뒤에 알려주면 늦다.
                // 휴지통을 언제 비우는지는 사용자 설정에 달려 있다. 기간을 약속하지 않는다.
                Text("휴지통을 비우기 전까지 복원할 수 있습니다.")
                    .font(R95.ui(11))
                    .foregroundStyle(R95.deep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            // 스타일의 padding까지 포함한 버튼 높이가 일정하도록 레이블에 높이를 준다.
            Button { onClean() } label: {
                HStack(spacing: 8) {
                    PixelIcon(art: .trash, size: 24)
                    Text(model.hasSelection ? "선택 항목 정리" : "선택한 항목 없음")
                        .font(R95.ui(14, bold: true))
                }
                .frame(minWidth: ItemTableColumns.actionButtonWidth - 26,
                       minHeight: ItemTableColumns.actionButtonHeight - 10)
            }
            .buttonStyle(Retro95ButtonStyle(isDefault: true))
            .disabled(!model.hasSelection)
        }
        .foregroundStyle(R95.black)
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: ItemTableColumns.actionHeight)
        .background(R95.gray)
        .retroRaised()
    }

    /// 남은 항목의 안전도 분포를 보여 기본 미선택인 위험 항목도 놓치지 않게 한다.
    private func distributionRow(_ level: SafetyLevel) -> some View {
        let count = model.items.filter { $0.safety == level }.count
        return HStack(spacing: 4) {
            SafetyChip(level: level, compact: true)
            Text("\(count)개")
                .font(R95.mono(11))
                // 영어 "7 items"는 폭이 모자라면 글자 단위로 세로로 꺾였다.
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(level.dockLabel) \(count)개")
    }
}

extension SafetyLevel {

    /// 독에 쓰는 이름. 등급 이름("안전")이 아니라 **무엇을 뜻하는지**를 적는다 —
    /// "안전 4개"보다 "다시 만들 수 있음 4개"가 고를 때 쓸모 있다.
    var dockLabel: String {
        switch self {
        case .safe: String(localized: "다시 만들 수 있음")
        case .caution: String(localized: "확인 필요")
        case .danger: String(localized: "되돌릴 수 없음")
        }
    }
}
