import SwiftUI
import AppKit

/// macOS 실물 투명 재질.
///
/// CSS `backdrop-filter`를 흉내내지 않는다. 반투명 회색을 깔아 흐림을 모사하면
/// 뒤가 비치지 않아 **탁한 회색 판**이 되고, 그 위 글자 대비가 무너진다
/// (예전 `selectionTint`가 정확히 그랬다 — 실측 1.54:1).
///
/// `NSVisualEffectView`는 창 뒤 내용을 실제로 샘플링해 흐린다. 다크/라이트 전환,
/// 창 활성/비활성, 접근성의 "투명도 줄이기"까지 시스템이 알아서 처리한다.
struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        // `.followsWindowActiveState`면 창이 비활성일 때 재질이 죽어
        // 사이드바가 본문과 같은 색으로 주저앉는다. 항상 켜 둔다.
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

extension View {
    /// 사이드바·독처럼 한 단 들어간 면에 쓰는 재질.
    func sidebarMaterial() -> some View {
        background(VisualEffect(material: .sidebar))
    }

    /// 창 전체 바탕. 툴바를 타이틀바에 통합할 때 그 아래로 이어진다.
    func windowMaterial() -> some View {
        background(VisualEffect(material: .underWindowBackground))
    }
}
