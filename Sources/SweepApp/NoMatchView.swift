import SwiftUI

/// 검색으로 아무것도 안 남았을 때.
///
/// **"정리할 항목이 없음"과 다른 화면이다.** 저쪽은 "지울 게 없다"는 좋은 소식이고,
/// 이쪽은 "찾는 게 없다"는 막다른 길이다. 같은 화면으로 묶으면 둘 다 잘못 읽힌다.
///
/// 예전에는 이 경우에 **아무것도 그리지 않았다.** 한글 입력 상태로 `xcode`를 쳤더니
/// `ㅌ쳉디`가 들어가 목록이 통째로 사라졌는데, 왜 사라졌는지 알 길이 없었다.
struct NoMatchView: View {
    let query: String
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Theme.Icon.large))
                .foregroundStyle(Theme.textTertiary)

            Text("맞는 항목이 없습니다")
                .font(Theme.title)
                .foregroundStyle(Theme.textPrimary)

            // **무엇을 쳤는지 되보여 준다.** 입력기가 글자를 바꿔 놓았어도
            // 그 사실이 화면에 있으면 바로 안다.
            Text("‘\(query)’와(과) 맞는 항목을 찾지 못했습니다.")
                .font(Theme.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .truncationMode(.middle)

            Button("검색어 지우기", action: onClear)
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
