import AppKit
import SwiftUI

/// 스크롤이 실제로 끊기는지 재는 도구. **측정이 끝나면 걷어낸다.**
///
/// `sample`은 메인 스레드 CPU만 본다. 합성(WindowServer)·GPU·추적영역에서 비용이 새면
/// 프로파일에는 0으로 찍히면서도 화면은 끊긴다 — 지난 작업이 정확히 그 함정에 빠졌다.
/// 프레임 간격은 그 전부를 포함한 **결과**다. 떨어진 프레임 수는 거짓말을 못 한다.
@MainActor
final class FrameProbe: NSObject {
    static let shared = FrameProbe()

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var intervals: [Double] = []

    /// 창에 붙은 뷰에서만 링크를 얻을 수 있다.
    ///
    /// **매번 다시 건다.** `link == nil`일 때만 걸었더니, 목록이 다시 만들어져
    /// 앵커 뷰가 갈리는 순간 옛 링크가 죽고 영영 재연결되지 않아 측정이 조용히 멈췄다.
    /// 계기가 멈춘 것을 "끊김 0"으로 읽을 뻔했다.
    func attach(to view: NSView) {
        link?.invalidate()
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        last = 0
        fputs("FRAME 링크 붙음\n", stderr)
        fflush(stderr)
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { last = link.timestamp }
        guard last > 0 else { return }
        intervals.append((link.timestamp - last) * 1000)
        if intervals.count >= 120 { report() }
    }

    private func report() {
        guard !intervals.isEmpty else { return }
        let sorted = intervals.sorted()
        let late = intervals.filter { $0 > 20 }.count
        let dropped = intervals.filter { $0 > 33 }.count
        let p50 = sorted[sorted.count / 2]
        let p95 = sorted[min(Int(Double(sorted.count) * 0.95), sorted.count - 1)]
        fputs(String(format: "FRAME n=%d p50=%.1fms p95=%.1fms max=%.1fms 늦음=%d 끊김=%d %@\n",
                     intervals.count, p50, p95, sorted[sorted.count - 1], late, dropped,
                     RowLifeProbe.summary), stderr)
        fflush(stderr)
        intervals.removeAll()
    }
}

/// `List` 뒤에 깔아 프레임 링크를 거는 앵커. 그리는 것은 없다.
struct FrameProbeAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { AnchorView() }
    func updateNSView(_ view: NSView, context: Context) {}

    final class AnchorView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            FrameProbe.shared.attach(to: self)
        }
    }
}
