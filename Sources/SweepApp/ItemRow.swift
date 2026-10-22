import AppKit
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

/// 열 폭을 헤더와 공유해 긴 경로가 있어도 숫자 열이 흔들리지 않게 한다.
struct ItemRow: View {
    let item: CleanupItem
    @Binding var isOn: Bool
    /// 헤더와 같은 값을 받아야 열이 어긋나지 않는다.
    var showsDates = true
    /// 헤더와 같은 값을 받아야 열이 어긋나지 않는다.
    var columns = ItemColumnLayout()
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
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
            Retro95Checkbox(state: isOn ? .on : .off)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                .accessibilityLabel(item.displayName)
                .accessibilityAction { isOn.toggle() }
                .frame(width: ItemTableColumns.check)

            Group {
                if item.category == .application {
                    Image(nsImage: ApplicationIconCache.icon(for: item.url.path))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                } else {
                    PixelIcon(art: item.category.pixelArt, size: 16)
                }
            }
            .frame(width: ItemTableColumns.icon)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(R95.ui(12, bold: true))
                    .foregroundStyle(isOn ? R95.white : R95.black)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // 이름만으로는 Cache가 어느 앱 것인지 알 수 없어 경로를 함께 보여준다.
                // 가운데를 잘라 긴 경로의 끝에 있는 구별 가능한 이름을 남긴다.
                Text(item.displayPath)
                    .font(R95.ui(10))
                    .foregroundStyle(isOn ? R95.light : R95.shadow)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, ItemTableColumns.padding)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Text(item.detail)
                    .font(R95.ui(12))
                    .foregroundStyle(isOn ? R95.white : (item.safety == .safe ? R95.deep : item.safety.tint))
                    // 위험·확인 항목은 선택 후에도 이유를 읽을 수 있어야 한다.
                    .lineLimit(item.safety == .safe ? 1 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if item.category == .application && item.safety == .danger {
                    ViewThatFits(in: .horizontal) {
                        Button("Finder에서 보기") { ItemActions.reveal(item.url) }
                            .fixedSize()
                        Button {
                            ItemActions.reveal(item.url)
                        } label: {
                            PixelIcon(art: .folder, size: 16)
                        }
                        .accessibilityLabel(Text("Finder에서 보기"))
                        .help(Text("Finder에서 보기"))
                    }
                    .buttonStyle(Retro95ButtonStyle())
                }
            }
            .padding(.horizontal, ItemTableColumns.padding)
            .frame(width: CGFloat(columns.width(.detail)), alignment: .leading)

            if showsDates {
                Text(item.datesLine() ?? "")
                    .font(R95.ui(11))
                    .foregroundStyle(isOn ? R95.light : R95.deep)
                    .lineLimit(1)
                    .padding(.horizontal, ItemTableColumns.padding)
                    .frame(width: CGFloat(columns.width(.dates)), alignment: .leading)
            }

            // 고른 것만 또렷하게 보여 훑을 때 담은 크기를 비교할 수 있다.
            Text(item.formattedSize)
                .font(R95.mono(12))
                .foregroundStyle(isOn ? R95.white : R95.shadow)
                .lineLimit(1)
                .padding(.horizontal, ItemTableColumns.padding)
                .frame(width: CGFloat(columns.width(.size)), alignment: .trailing)

            SafetyChip(level: item.safety)
                .frame(width: CGFloat(columns.width(.safety)))
        }
        .frame(height: R95.tableRowHeight)
        .background(isOn ? R95.navy : (isHovering ? R95.light : R95.white))
        .overlay(alignment: .bottom) { R95.light.frame(height: 1).allowsHitTesting(false) }
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle() }
        .onHover { isHovering = $0 }
        // 예전에는 스크롤 중 말풍선 때문에 생략했지만, 새 명세는 잘린 경로 전체를 요구한다.
        .help(item.displayPath)
        // 지우기 전에 열어 보고 경로를 복사할 길을 남긴다.
        .contextMenu {
            Button("Finder에서 보기") { ItemActions.reveal(item.url) }
            Button("위치 복사") { ItemActions.copyPath(item.url) }
        }
    }
}

/// AppKit icon lookup stays on the main actor; repeated row updates reuse the image.
@MainActor
private enum ApplicationIconCache {
    static let images: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 256
        return cache
    }()

    static func icon(for path: String) -> NSImage {
        let key = path as NSString
        if let image = images.object(forKey: key) { return image }
        let image = NSWorkspace.shared.icon(forFile: path)
        images.setObject(image, forKey: key)
        return image
    }
}
