import SwiftUI
import AppKit
import SweepKit

@main
struct SweepApp: App {

    init() {
        // 지난 실행에서 허락받은 폴더를 다시 연다. 첫 스캔보다 먼저여야
        // 스마트 스캔이 Xcode를 빠뜨리지 않는다 — `--scan-only`도 스캔이다.
        if Sandbox.isActive {
            FolderAccess.shared.restoreAll()
        }
        // 헤드리스 검증 경로. GUI는 자동으로 돌릴 수 없으므로
        // 스캔 파이프라인 전체를 확인할 수 있는 입구를 열어 둔다.
        if CommandLine.arguments.contains("--scan-only") {
            Self.runScanAndExit()
        }
        // 같은 취지의 입구. CPU 쪽은 **샌드박스에서도 되는지**를 확인하는 수단이기도
        // 하다 — 서명한 번들 안에서 이 명령을 돌려 목록이 비지 않는지 본다.
        if CommandLine.arguments.contains("--cpu-only") {
            Self.runCPUSampleAndExit()
        }
        _app = State(initialValue: AppModel())
        // SPM 실행 파일은 앱 번들이 아니라서 기본이 백그라운드 프로세스다.
        // .regular로 올려야 창이 앞으로 나오고 메뉴 막대가 붙는다.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    /// 메뉴 명령이 모델을 건드려야 해서 창이 아니라 앱이 들고 있는다.
    ///
    /// 선언에서 바로 만들지 않는다. 프로퍼티 초기값은 `init` 본문보다 먼저 돌아서,
    /// 폴더 허락을 복원하기 전에 모델이 "허락 필요"로 굳는다 — 실측에서
    /// 다시 열 때마다 허락 화면이 떴다. `init`에서 복원한 뒤에 만든다.
    @State private var app: AppModel

    /// 상태 아이콘에서 본 창을 앞으로 부를 때 쓴다.
    @Environment(\.openWindow) private var openWindow

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
        .commands { SweepCommands(app: app) }

        // 배터리·와이파이가 있는 상태 영역. 창을 닫아도 여기는 남는다.
        MenuBarExtra("Sweep", systemImage: "sparkles") {
            MenuBarPanel(app: app) {
                openWindow(id: "main")
                // 다른 앱이 앞에 있으면 창만 만들어지고 뒤에 숨는다
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        // 기본 `.menu`는 임의 뷰를 그리지 못한다 — 텍스트 항목만 나온다
        .menuBarExtraStyle(.window)
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

    /// 지금 CPU를 쓰는 프로세스를 탭 구분 텍스트로 찍고 종료한다.
    ///
    /// 누적값은 두 번 재야 뜻이 생기므로 구간만큼 멈춘다. 여기서는 `Task.sleep`이
    /// 아니라 `Thread.sleep`이다 — `init()`이 async가 아니라 await할 자리가 없다.
    private static func runCPUSampleAndExit() -> Never {
        let interval = Duration.seconds(2)
        let before = ProcessCPUSampler.tick()
        Thread.sleep(forTimeInterval: 2)
        let usage = ProcessUsage.compute(
            from: before, to: ProcessCPUSampler.tick(), over: interval)

        // 화면과 같은 상한으로 자른다. 전체를 찍으면 검증할 때 눈으로 볼 수 없다.
        for item in usage.prefix(20) {
            print([
                item.formattedPercent,
                String(item.pid),
                item.name,
                item.executablePath ?? "-",
            ].joined(separator: "\t"))
        }
        // 읽은 수와 **그중 쓰고 있는 수**를 따로 적는다. 앞의 것이 0이면 수집이
        // 막힌 것이고, 뒤의 것만 0이면 정말 아무도 안 쓴 것이다.
        print("측정 \(before.count)개 · 사용 중 \(usage.count)개")
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
