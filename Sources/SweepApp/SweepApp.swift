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

    var body: some Scene {
        WindowGroup("Sweep") {
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
        }
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
