import SwiftUI
import SweepKit

/// 전체 디스크 접근이 꺼져 있을 때만 보이는 줄.
///
/// **켜면 무엇이 좋아지는지를 말한다.** "권한이 필요합니다"만 쓰면 왜 켜야 하는지
/// 알 수 없어 그냥 닫는다.
///
/// 이 스위치 하나가 "다른 앱의 데이터에 접근하려고 합니다"를 없앤다. 그 물음은
/// **앱 폴더마다 따로** 뜨기 때문에 한 번 허용으로는 끝나지 않는다 — 실제로
/// 사용자가 "왜 자꾸 묻냐"고 한 것이 그 때문이다.
struct FullDiskAccessBanner: View {

    /// 꺼진 것이 확실할 때만. 샌드박스(App Store 빌드)에서도 쓴다 — `~/.Trash`와 다른 앱의
    /// 데이터는 폴더를 허용해도 이것 없이는 열리지 않는다(실측).
    /// 화면은 되도록 `AppModel.hasFullDiskAccess`를 본다. 켜고 돌아오면 따라온다.
    static var isNeeded: Bool { FullDiskAccess.isMissing() }

    /// 켜면 무엇이 좋아지는지. 화면마다 얻는 것이 달라 바꿔 끼운다.
    var message = String(localized: "시스템 설정의 전체 디스크 접근에서 Sweep을 켜 주세요. 앱이 다시 쓰려고 저장한 파일도 찾을 수 있어요. 앱마다 파일을 열어도 되는지 묻는 창도 더는 뜨지 않아요.")

    var body: some View {
        HStack(spacing: 12) {
            PixelIcon(art: .warning, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("휴지통과 앱이 저장한 파일도 찾아보세요")
                    .font(Theme.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 12)

            Button("시스템 설정 열기") { PrivacySettings.openFullDiskAccess() }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(R95.gray)
        .retroRaised()
        .buttonStyle(Retro95ButtonStyle())
    }
}
