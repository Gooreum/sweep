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

    /// 샌드박스(App Store 빌드)에서는 전체 디스크 접근이 의미가 없다.
    /// 켜 줄 수도 없는 것을 켜라고 하면 안 된다.
    static var isNeeded: Bool { !Sandbox.isActive && !FullDiskAccess.isGranted }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.open")
                .font(.system(size: Theme.Icon.small))
                .foregroundStyle(SafetyLevel.caution.tint)
                .frame(width: Theme.Icon.medium)

            VStack(alignment: .leading, spacing: 2) {
                Text("전체 디스크 접근이 꺼져 있습니다")
                    .font(Theme.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                Text("켜면 앱 캐시까지 찾고, ‘다른 앱의 데이터’ 물음이 더 뜨지 않습니다.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 12)

            Button("시스템 설정 열기") { PrivacySettings.openFullDiskAccess() }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
