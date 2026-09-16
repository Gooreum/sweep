import AppKit

/// 지금 실행 중인 앱의 번들 경로.
///
/// SweepKit에서 **AppKit을 쓰는 유일한 곳**이다. 관문이 이 타입을 직접 부르지 않고
/// 갈아끼울 수 있는 함수로 들고 있는 이유도 그것이다 — 테스트에서 앱을 띄울 수는 없다.
enum RunningApplications {

    /// 번들이 없는 프로세스(데몬 등)는 빠진다.
    static var urls: [URL] {
        NSWorkspace.shared.runningApplications.compactMap(\.bundleURL)
    }
}
