import SwiftUI
import SweepKit

/// 옮기지 못한 항목 목록. 툴팁에 숨어 있던 것을 **호버 없이** 보여준다.
///
/// 행마다 "왜"와 "그래서 무엇을"을 같이 둔다. 사유만 보여주면 사용자는
/// 다음에 무엇을 해야 하는지 모른 채 같은 버튼을 다시 누른다.
///
/// 정리 실패와 되돌리기 실패를 같은 시트로 보여준다. 되돌리기 실패는 다시 시도할 것이
/// 없고(휴지통에서 직접 꺼내야 한다), "Finder에서 보기"는 휴지통 안의 항목을 가리킨다.
struct RemovalFailuresSheet: View {
    let failed: [RemovalOutcome]
    let title: String
    let subtitle: String
    let onClose: () -> Void
    /// nil이면 재시도 버튼을 두지 않는다.
    let onRetry: (() -> Void)?
    let revealURL: (RemovalOutcome) -> URL
    /// 휴지통에서 직접 꺼내야 할 때 휴지통을 열어 준다.
    let offersTrash: Bool
    /// 휴지통을 열 권한을 그 자리에서 받을 때 쓴다.
    let app: AppModel?

    init(failed: [RemovalOutcome],
         title: String? = nil,
         subtitle: String = String(localized: "아래 파일은 그대로 남아 있어요. 각 파일 아래 안내를 따라 문제를 해결한 뒤 ‘실패한 것만 다시 시도’를 눌러 주세요."),
         revealURL: @escaping (RemovalOutcome) -> URL = { $0.item.url },
         offersTrash: Bool = false,
         app: AppModel? = nil,
         onClose: @escaping () -> Void,
         onRetry: (() -> Void)?) {
        self.failed = failed
        self.title = title ?? String(localized: "\(failed.count)개는 정리하지 못했어요")
        self.subtitle = subtitle
        self.revealURL = revealURL
        self.offersTrash = offersTrash
        self.app = app
        self.onClose = onClose
        self.onRetry = onRetry
    }

    /// 권한 실패가 있고 전체 디스크 접근이 꺼진 것이 확실할 때만 설정 버튼을 둔다.
    /// 샌드박스(App Store)에서도 둔다 — 안내 문구가 이것을 켜라고 하는데 버튼이 없으면 막힌다.
    private var offersFullDiskAccess: Bool {
        FullDiskAccessBanner.isNeeded && failed.contains { $0.failure?.kind == .permissionDenied }
    }

    var body: some View {
        Retro95Dialog(title: title, icon: .warning) {
            VStack(alignment: .leading, spacing: 12) {
                Text(subtitle)
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
            if failed.contains(where: {
                $0.item.category == .application && $0.failure?.kind == .permissionDenied
            }) {
                Button("앱 관리 설정 열기") { PrivacySettings.openAppManagement() }
                    .buttonStyle(Retro95ButtonStyle())
            }
            if offersFullDiskAccess {
                Button("전체 디스크 접근 설정 열기") { PrivacySettings.openFullDiskAccess() }
                    .buttonStyle(Retro95ButtonStyle())
            }
            if offersTrash {
                TrashOpenButton(app: app,
                                fallback: "Finder에서 휴지통을 열어 주세요. 파일을 마우스 오른쪽 버튼으로 누르고 ‘되돌려 놓기’를 고르면 원래 위치로 돌아가요.")
                    .buttonStyle(Retro95ButtonStyle())
            }
            if let onRetry {
                Button("닫기", action: onClose)
                    .buttonStyle(Retro95ButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("실패한 것만 다시 시도", action: onRetry)
                    .buttonStyle(Retro95ButtonStyle(isDefault: true))
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("닫기", action: onClose)
                    .buttonStyle(Retro95ButtonStyle(isDefault: true))
                    .keyboardShortcut(.defaultAction)
            }
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
            Button("Finder에서 보기") { ItemActions.reveal(revealURL(outcome)) }
                .buttonStyle(Retro95ButtonStyle())
        }
        .padding(.vertical, 10)
    }
}

extension RemovalFailuresSheet {
    /// 되돌리기 실패. 다시 시도할 것이 없고, 휴지통 안의 항목을 가리킨다.
    /// 샌드박스가 휴지통에서 꺼내는 것을 막으면 이 시트가 Finder로 넘겨주는 길이다.
    static func restore(_ failed: [RemovalOutcome], app: AppModel? = nil,
                        onClose: @escaping () -> Void) -> RemovalFailuresSheet {
        RemovalFailuresSheet(
            failed: failed,
            title: String(localized: "\(failed.count)개는 아직 복구되지 않았어요"),
            subtitle: String(localized: "휴지통에서 파일을 찾아 마우스 오른쪽 버튼으로 누르고 ‘되돌려 놓기’를 골라 주세요. 휴지통을 이미 비웠다면 복구할 수 없어요."),
            revealURL: { $0.trashedURL ?? $0.item.url },
            offersTrash: true,
            app: app,
            onClose: onClose,
            onRetry: nil)
    }
}
