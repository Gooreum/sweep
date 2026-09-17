import SwiftUI
import SweepKit

extension SafetyLevel {

    /// 안전도를 나타내는 아이콘.
    ///
    /// **안전에는 색을 쓰지 않는다.** 안전이 기본값이라 목록 대부분이 안전인데,
    /// 거기에 초록 알약을 붙이면 화면이 통째로 색으로 덮여 정작 위험한 것이 묻힌다.
    /// 예전 `SafetyBadge`가 그랬다.
    var symbolName: String {
        switch self {
        case .safe: "circle"
        case .caution: "exclamationmark.triangle"
        case .danger: "lock.fill"
        }
    }

    /// 아이콘과 설명글에 쓰는 색. 안전은 무채색이다.
    ///
    /// 값은 `Theme`에 있다 — 화면에서 hex를 직접 쓰지 않는다.
    var tint: Color {
        switch self {
        case .safe: Theme.textTertiary
        case .caution: Theme.cautionText
        case .danger: Theme.dangerText
        }
    }
}

/// 정리 후보 한 줄. 체크박스 · 안전도 아이콘 · (이름 + 설명) · 크기.
///
/// 높이 56. 예전에는 이름 옆에 색 배지가, 왼쪽에 3pt 경고 바가 있었다.
/// 배지를 아이콘 한 칸으로 바꾸고 경고 바를 없애 이름이 시작하는 x가 모든 행에서 같아졌다.
struct ItemRow: View {
    let item: CleanupItem
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            // 되돌릴 수 없는 항목도 **고를 수는 있다.**
            //
            // 한때 아예 막아 뒀는데, 그러면 진짜로 지우려는 사람이 앱에서 할 방법이
            // 없어진다 — 심사 제출본을 정리하는 것도 정당한 작업이다.
            // 실수 방지는 기본 미선택 · 자물쇠 아이콘 · 확인 시트가 맡는다.
            //
            // **`Toggle(.checkbox)`를 쓰지 않는다.** 그것은 행마다 AppKit `NSButton`을
            // 하나씩 만드는데, `List`는 화면 밖으로 나간 행의 뷰를 **재사용하지 않고**
            // 버렸다가 다시 만든다(실측: 한 번 훑는 동안 만듦 69 · 버림 72, 갱신 69 —
            // 갱신 수가 만듦 수와 같다는 것이 재사용이 0이라는 뜻이다).
            // 그래서 빠르게 굴리면 `NSButton`이 초당 수십 개씩 만들어졌다 버려진다.
            //
            // 실측(항목 57개, 같은 조건 3회, 떨어진 프레임 수):
            //   체크박스 없는 최소 행       → 0 / 1 / 2
            //   거기에 `Toggle(.checkbox)`  → 35 / 24 / 35   ← 버벅임이 전부 여기서 나왔다
            //   거기에 아래의 그린 체크박스 → 1 / 3 / 0
            //
            // 그려서 쓰면 모양은 같고 비용이 없다. 누르는 것은 행 전체 탭이 맡는다.
            // 글자 블록과 같은 높이를 주고 위로 붙인다. 안 그러면 세 줄 블록의
            // **가운데**에 맞춰져 이름보다 한 줄 아래로 내려간다 — 실기에서 그랬다.
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: Theme.checkboxSize))
                .foregroundStyle(isOn ? Color.accentColor : Theme.textTertiary)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                .accessibilityLabel(item.displayName)
                .frame(height: Theme.rowTextBlockHeight, alignment: .top)

            // 등급마다 도형이 달라도 이름 열이 흔들리지 않게 칸을 고정한다.
            Image(systemName: item.safety.symbolName)
                .font(.system(size: Theme.safetyIconSlot))
                .foregroundStyle(item.safety.tint)
                .frame(width: Theme.safetyIconSlot + 4,
                       height: Theme.rowTextBlockHeight, alignment: .top)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(Theme.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // 설명이 비어도 **자리는 남긴다.** 안 그러면 경로가 둘째 줄로 올라와
                // 행마다 셋째 줄의 위치가 달라진다.
                Text(item.detail)
                    .font(Theme.caption)
                    // 위험도가 여기서 한 번 더 읽힌다 — 아이콘만으로는 작다.
                    .foregroundStyle(item.safety == .safe
                                     ? Theme.textSecondary : item.safety.tint)
                    .lineLimit(1)
                    .frame(height: Theme.rowDetailLineHeight, alignment: .leading)

                // 이름만으로는 무엇인지 알 수 없는 항목이 많다 — `Cache`가 어느 앱 것인지,
                // UUID 폴더가 어느 기기인지는 경로를 봐야 안다.
                //
                // **가운데를 자른다.** 끝을 자르면 긴 경로가 전부
                // `~/Library/Developer/…`로 끝나 서로 구분되지 않는다.
                Text(item.displayPath)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            // 두 열의 높이를 맞춰 **이름과 크기가 같은 선에** 놓이게 한다.
            // 한쪽만 두 줄이면 SwiftUI가 각자 가운데를 맞춰 첫 줄이 어긋난다.
            .frame(height: Theme.rowTextBlockHeight, alignment: .topLeading)

            Spacer(minLength: 12)

            // 우측은 크기와 날짜 두 줄. 값끼리 세로로 비교할 수 있게 오른쪽 정렬한다.
            // 고른 것만 또렷하게 — 훑을 때 무엇을 담았는지가 숫자로 보인다.
            VStack(alignment: .trailing, spacing: 3) {
                Text(item.formattedSize)
                    .font(Theme.bodyMono)
                    .foregroundStyle(isOn ? Theme.textPrimary : Theme.textTertiary)

                if let datesLine = item.datesLine() {
                    Text(datesLine)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: Theme.rowMetaWidth, height: Theme.rowTextBlockHeight,
                   alignment: .topTrailing)
        }
        .padding(.horizontal, 24)
        .frame(height: Theme.rowHeightComfortable)
        // 면을 통째로 칠하지 않고 9%만 얹는다. 예전에는 불투명 `surfaceRaised`였는데,
        // 목록의 절반이 선택된 상태에서 화면이 두 덩어리로 갈려 보였다.
        .background(isOn ? Theme.rowSelected : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
        // **툴팁을 달지 않는다.** 마우스를 올린 채로 목록을 훑으면 행마다 말풍선이
        // 떴다 사라져 거슬린다. 담겨 있던 것은 이제 전부 행에 있다 —
        // 경로는 셋째 줄에, 날짜는 우측 열에, 위험 표시는 자물쇠 아이콘에.
        //
        // 경로가 잘려 보일 때 전체를 보려면 우클릭 → 경로 복사를 쓴다.
        //
        // 지우기 전에 **열어 보는 길**이 있어야 한다. 정리 목록에는 그게 없었다.
        .contextMenu {
            Button("Finder에서 보기") { ItemActions.reveal(item.url) }
            Button("경로 복사") { ItemActions.copyPath(item.url) }
        }
    }
}
