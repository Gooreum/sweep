import SwiftUI
import SweepKit

/// 검색을 시작하는 주 동작 버튼. 세 화면(명령줄·스마트 스캔 첫 화면·기능 탭 첫 화면)이
/// 같은 모양을 써서, 어느 탭에서든 "큰 돋보기 버튼 = 검색"으로 읽힌다.
///
/// 정리 독의 "선택 항목 정리"와 같은 크기 언어다 — 24px 픽셀 아이콘 + 14pt 굵은 글자.
/// 명령줄의 12pt 회색 버튼은 회색 바탕 위에서 눈에 띄지 않아 사용자가 찾지 못했다.
struct ScanButton: View {
    @Bindable var model: ScanModel
    /// 스마트 스캔은 "전체 검색", 기능 탭은 "검색".
    var title: String = String(localized: "검색")
    /// ⌘R 힌트를 함께 보여줄지. 명령줄에서는 켜고 대화상자 안에서는 끈다.
    var showsShortcut = false

    var body: some View {
        Button {
            Task { await model.scan() }
        } label: {
            HStack(spacing: 8) {
                PixelIcon(art: .magnifier, size: 24)
                // 도는 중에는 왜 못 누르는지 글자로 말한다. 회색만 되면 고장처럼 보인다.
                Text(model.isBusy ? String(localized: "검색 중…") : title)
                    .font(R95.ui(14, bold: true))
                if showsShortcut {
                    Text(verbatim: "⌘R")
                        .font(R95.ui(11))
                        .foregroundStyle(R95.deep)
                }
            }
            .frame(minWidth: 140, minHeight: ItemTableColumns.actionButtonHeight - 10)
        }
        .buttonStyle(Retro95ButtonStyle(isDefault: true))
        .disabled(model.isBusy)
        .accessibilityLabel(title)
        .accessibilityHint(Text(verbatim: "⌘R"))
    }
}
