import SwiftUI
import SweepKit

/// 휴지통에 남았지만 Sweep이 지울 수 없는 것을 알리는 줄.
///
/// 관리자 소유 항목(설치 패키지로 깔린 앱을 버린 것)은 관문이 막아 목록에 없다.
/// 알리지 않으면 Sweep으로 다 비웠는데 Finder 휴지통에 왜 남는지 알 수 없다.
/// **지우는 길을 같이 준다** — Finder에서 비우면 암호를 묻고 지운다.
struct TrashLeftoverNotice: View {
    let leftovers: [URL]

    private var names: String {
        let first = leftovers.first?.lastPathComponent ?? ""
        return leftovers.count > 1
            ? String(localized: "\(first) 외 \(leftovers.count - 1)개")
            : first
    }

    var body: some View {
        HStack(spacing: 12) {
            PixelIcon(art: .warning, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("관리자 소유 항목 \(leftovers.count)개(\(names))는 Sweep이 지울 수 없어요")
                    .font(Theme.bodyText)
                    .foregroundStyle(Theme.textPrimary)
                Text("Finder에서 휴지통을 비우면 Mac 암호를 물은 뒤 지워요.")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 12)

            Button("휴지통 열기") { _ = ItemActions.openTrash() }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(R95.gray)
        .retroRaised()
        .buttonStyle(Retro95ButtonStyle())
    }
}
