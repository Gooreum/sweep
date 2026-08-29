import SwiftUI
import AppKit
import SweepKit

@main
struct SweepApp: App {

    init() {
        // 헤드리스 검증 경로. GUI는 자동으로 돌릴 수 없으므로
        // 스캔 파이프라인 전체를 확인할 수 있는 입구를 열어 둔다.
        if CommandLine.arguments.contains("--scan-only") {
            Self.runScanAndExit()
        }
        // SPM 실행 파일은 앱 번들이 아니라서 기본이 백그라운드 프로세스다.
        // .regular로 올려야 창이 앞으로 나오고 메뉴 막대가 붙는다.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    /// 메뉴 명령이 모델을 건드려야 해서 창이 아니라 앱이 들고 있는다.
    @State private var app = AppModel()

    var body: some Scene {
        // `WindowGroup`이 아니라 `Window`다. 창마다 `AppModel`이 따로 생기면
        // 같은 43초 스캔이 두 번 돈다. 창을 여러 개 열 이유가 없는데
        // "New Window"와 탭 항목만 메뉴에 남는다.
        Window("Sweep", id: "main") {
            // 화면 단계는 실제 스캔 없이는 재현하기 어렵다. 43초를 기다리거나
            // 실제 파일을 지워야 완료 화면을 볼 수 있으면 검증할 수 없다.
            // `--scan-only`와 같은 취지의 확인용 입구다.
            if let stage = StageHarness.requested {
                StageHarness(stage: stage)
                    .frame(minWidth: 940, minHeight: 600)
            } else {
                ContentView(app: app)
                    // 사이드바 220 + 결과 목록이 접히지 않을 최소 폭
                    .frame(minWidth: 940, minHeight: 600)
            }
        }
        .defaultSize(width: Theme.windowWidth, height: Theme.windowHeight)
    }

    /// 스캔 결과를 탭 구분 텍스트로 찍고 종료한다.
    private static func runScanAndExit() -> Never {
        let items = runBlocking { await ScanCoordinator.standard().scan() }

        for item in items {
            print([
                item.category.rawValue,
                item.safety.rawValue,
                item.formattedSize,
                item.url.path,
            ].joined(separator: "\t"))
        }
        print("총 \(items.count)개 · \(items.formattedTotalSize)")
        exit(0)
    }

    /// `init()`은 async가 아니므로 세마포어로 비동기 스캔이 끝나기를 기다린다.
    private static func runBlocking<T: Sendable>(
        _ work: @escaping @Sendable () async -> T
    ) -> T {
        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var result: T?
        Task.detached {
            result = await work()
            semaphore.signal()
        }
        semaphore.wait()
        return result!
    }
}
