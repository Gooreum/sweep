import SwiftUI
import SweepKit

/// 옮기지 못한 항목 목록. 툴팁에 숨어 있던 것을 **호버 없이** 보여준다.
///
/// 행마다 "왜"와 "그래서 무엇을"을 같이 둔다. 사유만 보여주면 사용자는
/// 다음에 무엇을 해야 하는지 모른 채 같은 버튼을 다시 누른다.
struct RemovalFailuresSheet: View {
    let failed: [RemovalOutcome]
    let onClose: () -> Void
    let onRetry: () -> Void

    /// 권한 실패가 있고 이 빌드에서 켤 수 있을 때만 설정 버튼을 둔다.
    /// 샌드박스(App Store)에서는 전체 디스크 접근이 뜻이 없다 — `FullDiskAccessBanner`와 같은 판단.
    private var offersFullDiskAccess: Bool {
        FullDiskAccessBanner.isNeeded && failed.contains { $0.failure?.kind == .permissionDenied }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(failed.count)개 항목을 옮기지 못했습니다")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("사유를 확인하고 조치한 뒤 실패한 것만 다시 시도할 수 있습니다.")
                .font(Theme.bodyText)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(failed, id: \.item.url) { outcome in
                        row(outcome)
                        Divider().overlay(Theme.border)
                    }
                }
            }
            .frame(maxHeight: 320)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 16)

            HStack(spacing: 10) {
                if offersFullDiskAccess {
                    Button("전체 디스크 접근 설정 열기") { PrivacySettings.openFullDiskAccess() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Spacer()
                Button("닫기", action: onClose)
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("실패한 것만 다시 시도", action: onRetry)
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 22)
        }
        .padding(26)
        .frame(width: 560)
        .background(Theme.surfaceRaised)
    }

    private func row(_ outcome: RemovalOutcome) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(outcome.item.displayName)
                    .font(Theme.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                // 경로는 가운데를 줄인다. 앞(어느 폴더 아래)과 끝(무슨 파일)이 둘 다 정보다.
                Text(outcome.item.displayPath)
                    .font(Theme.captionMono)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let reason = outcome.failureReason {
                    Text(reason)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.dangerText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let advice = outcome.failure?.kind.advice {
                    Text(advice)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 12)
            Button("Finder에서 보기") { ItemActions.reveal(outcome.item.url) }
        }
        .padding(.vertical, 10)
    }
}
