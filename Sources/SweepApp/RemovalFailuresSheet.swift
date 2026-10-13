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
        Retro95Dialog(title: "\(failed.count)개 항목을 옮기지 못했습니다", icon: .warning) {
            VStack(alignment: .leading, spacing: 12) {
                Text("사유를 확인하고 조치한 뒤 실패한 것만 다시 시도할 수 있습니다.")
                    .foregroundStyle(R95.deep)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(failed, id: \.item.url) { outcome in
                            row(outcome)
                            Retro95Separator()
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(maxHeight: 320)
                .fixedSize(horizontal: false, vertical: true)
                .background(R95.white)
                .retroSunken()
            }
        } buttons: {
            if offersFullDiskAccess {
                Button("전체 디스크 접근 설정 열기") { PrivacySettings.openFullDiskAccess() }
                    .buttonStyle(Retro95ButtonStyle())
            }
            Button("닫기", action: onClose)
                .buttonStyle(Retro95ButtonStyle())
                .keyboardShortcut(.cancelAction)
            Button("실패한 것만 다시 시도", action: onRetry)
                .buttonStyle(Retro95ButtonStyle(isDefault: true))
                .keyboardShortcut(.defaultAction)
        }
        .frame(width: 560)
        .background(R95.gray)
    }

    private func row(_ outcome: RemovalOutcome) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(outcome.item.displayName)
                    .font(R95.ui())
                    .foregroundStyle(R95.black)
                // 경로는 가운데를 줄인다. 앞(어느 폴더 아래)과 끝(무슨 파일)이 둘 다 정보다.
                Text(outcome.item.displayPath)
                    .font(R95.mono(11))
                    .foregroundStyle(R95.deep)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let reason = outcome.failureReason {
                    Text(reason)
                        .font(R95.ui(11))
                        .foregroundStyle(R95.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let advice = outcome.failure?.kind.advice {
                    Text(advice)
                        .font(R95.ui(11))
                        .foregroundStyle(R95.deep)
                }
            }
            Spacer(minLength: 12)
            Button("Finder에서 보기") { ItemActions.reveal(outcome.item.url) }
                .buttonStyle(Retro95ButtonStyle())
        }
        .padding(.vertical, 10)
    }
}
