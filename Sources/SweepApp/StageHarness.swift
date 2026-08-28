import SwiftUI
import SweepKit

/// 화면 단계를 하나씩 띄워 눈으로 확인하는 입구. `--stage <이름>`.
///
/// 스캔은 43초가 걸리고 정리는 되돌릴 수 없어서, 실제 흐름으로는
/// "검색 중"과 "정리 완료" 화면을 확인할 방법이 없다.
/// `ScanModel`의 주입 지점만 쓰고 새 우회로를 뚫지 않는다 —
/// 여기서 보이는 것은 실제 코드가 그리는 것과 같다.
struct StageHarness: View {
    let stage: String

    static var requested: String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--stage"), index + 1 < args.count
        else { return nil }
        return args[index + 1]
    }

    @State private var model: ScanModel?
    @State private var app = AppModel()

    var body: some View {
        Group {
            if let model {
                if stage.hasPrefix("smart-") {
                    SmartScanView(app: app, model: model)
                } else {
                    FeatureScreen(feature: .junk, model: model)
                }
            } else {
                Text("준비 중").font(Theme.bodyText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.contentBackground)
        .task { await build() }
    }

    private func build() async {
        let items = [
            CleanupItem(url: URL(filePath: "/private/tmp/큰캐시.bin"), size: 5_368_709_120,
                        category: .devCache, safety: .safe, detail: "Homebrew 내려받기 캐시"),
            CleanupItem(url: URL(filePath: "/private/tmp/보관함"), size: 234_881_024,
                        category: .xcode, safety: .danger, detail: "다시 만들 수 없음"),
        ]

        switch stage {
        case "idle":
            model = ScanModel(scan: { AsyncStream { $0.finish() } })

        case "scanning":
            // 끝나지 않는 스트림 — 검색 중 화면에 머문다
            let created = ScanModel(scan: {
                AsyncStream { continuation in
                    continuation.yield(ScanCoordinator.Progress(
                        items: items, fraction: 0.43, elapsed: .seconds(9),
                        estimatedRemaining: .seconds(12),
                        finishedScanners: 2, totalScanners: 4))
                }
            })
            model = created
            Task { await created.scan() }

        case "results":
            let created = ScanModel(scan: { Self.finishing(items) })
            model = created
            await created.scan()

        case "cleaned":
            let created = ScanModel(scan: { Self.finishing(items) },
                                    removeOne: { RemovalOutcome(item: $0, failureReason: nil) })
            model = created
            await created.scan()
            await created.removeSelected()

        case "cleaned-failed":
            let created = ScanModel(scan: { Self.finishing(items) },
                                    removeOne: {
                                        RemovalOutcome(item: $0, failureReason: "보호된 경로입니다")
                                    })
            model = created
            await created.scan()
            await created.removeSelected()

        case "danger-only":
            // 되돌릴 수 없는 항목만 있으면 기본 선택이 비어 정리 버튼이 잠긴다
            let onlyDanger = [
                CleanupItem(url: URL(filePath: "/private/tmp/보관함"), size: 234_881_024,
                            category: .xcode, safety: .danger, detail: "다시 만들 수 없음"),
            ]
            let created = ScanModel(scan: { Self.finishing(onlyDanger) })
            model = created
            await created.scan()

        case "smart-summary":
            // 기능마다 다른 카테고리를 심어 카드가 제각기 채워지는지 본다
            let spread = items + [
                CleanupItem(url: URL(filePath: "/private/tmp/큰영상.mov"), size: 1_073_741_824,
                            category: .largeFile, safety: .caution),
                CleanupItem(url: URL(filePath: "/private/tmp/사본.zip"), size: 104_857_600,
                            category: .duplicate, safety: .safe),
            ]
            let created = ScanModel(scan: { Self.finishing(spread) })
            model = created
            await created.scan()

        case "smart-summary-partial":
            // 중복이 하나도 없는 경우 — 그 카드는 비활성이어야 한다
            let created = ScanModel(scan: { Self.finishing(items) })
            model = created
            await created.scan()

        case "smart-scanning":
            let created = ScanModel(scan: {
                AsyncStream { continuation in
                    continuation.yield(ScanCoordinator.Progress(
                        items: items, fraction: 0.67, elapsed: .seconds(20),
                        estimatedRemaining: .seconds(95),
                        finishedScanners: 4, totalScanners: 6))
                }
            })
            model = created
            Task { await created.scan() }

        case "empty":
            let created = ScanModel(scan: { Self.finishing([]) })
            model = created
            await created.scan()

        default:
            model = ScanModel(scan: { AsyncStream { $0.finish() } })
        }
    }

    /// 스트림을 만들 뿐 화면 상태를 건드리지 않는다.
    /// 메인 액터에 묶어 두면 `@Sendable` 클로저 안에서 부를 수 없다.
    nonisolated private static func finishing(_ items: [CleanupItem])
        -> AsyncStream<ScanCoordinator.Progress> {
        AsyncStream { continuation in
            continuation.yield(ScanCoordinator.Progress(
                items: items, fraction: 1, elapsed: .seconds(3),
                estimatedRemaining: nil, finishedScanners: 4, totalScanners: 4))
            continuation.finish()
        }
    }
}
