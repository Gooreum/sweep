import AppKit
import SwiftUI

/// 행을 그리는 **AppKit 뷰**가 재사용되는지, 매번 새로 만들어지는지를 센다.
/// **측정이 끝나면 걷어낸다.**
///
/// SwiftUI `View` 값(`ItemRow.body`)이 몇 번 도는지와 그 아래 `NSView`가 몇 개 만들어지는지는
/// **다른 층이고 답도 다를 수 있다.** 지난 측정에서 본문 층은 이미 답이 나왔다
/// (10초 스크롤에 33 → 87, 63개 항목에 행마다 대략 한 번). 아직 답이 없는 것이 이쪽이다.
///
/// 63개 목록을 10초 굴렸을 때:
/// - `made` 증가량이 수십 → 재사용되고 있다 (새로 보인 행만큼만 만들어졌다)
/// - `made` 증가량이 수백 이상 → **매번 새로 만들고 있다**
/// - `made`는 작은데 `updated`가 크다 → 재사용은 되는데 갱신이 과하다 (처방이 다르다)
struct RowLifeProbe: NSViewRepresentable {
    let id: URL

    func makeNSView(context: Context) -> NSView {
        RowLifeProbe.made += 1
        return NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        RowLifeProbe.updated += 1
    }

    static func dismantleNSView(_ view: NSView, coordinator: ()) {
        RowLifeProbe.destroyed += 1
    }

    nonisolated(unsafe) static var made = 0
    nonisolated(unsafe) static var updated = 0
    nonisolated(unsafe) static var destroyed = 0

    /// 프레임 보고에 같이 실어 **같은 구간의 숫자**를 보게 한다.
    /// 따로 찍으면 어느 스크롤 구간의 값인지 맞춰 볼 수 없다.
    static var summary: String {
        "ROWLIFE made=\(made) updated=\(updated) destroyed=\(destroyed)"
    }
}
