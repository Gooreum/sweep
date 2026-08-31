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
    /// `body`에서 만들면 렌더마다 새 모델이 되어 트리가 매번 초기화된다.
    @State private var diskMap: DiskMapModel?
    @State private var app = AppModel()

    var body: some View {
        Group {
            if stage == "diskmap" {
                if let diskMap {
                    DiskMapView(model: diskMap)
                } else {
                    Text("준비 중").font(Theme.bodyText)
                }
            } else if let model {
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
        .background(Theme.surface)
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

        case "diskmap":
            // `body`가 `DiskMapView`를 직접 그린다 — 여기서 `ScanModel`은 쓰이지 않는다.
            // `default`로 흘려보내면 쓰지도 않을 모델을 만들고, 하니스 단계 목록에서도
            // 빠져 config와 어긋난다.
            diskMap = Self.seededDiskMap()

        default:
            model = ScanModel(scan: { AsyncStream { $0.finish() } })
        }
    }

    /// 실제 순회는 10초가 넘는다. 트리를 손으로 넣어 목록·컨텍스트 메뉴·
    /// 확인 대화를 눈으로 확인할 수 있게 한다.
    @MainActor
    private static func seededDiskMap() -> DiskMapModel {
        let caches = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Caches")

        // 자식은 **실재하지 않는** 경로를 가리킨다.
        // 하니스는 우클릭·확인 대화를 눈으로 보려고 띄우는 화면이라, 여기서
        // 실수로 "휴지통으로 이동"을 눌러도 지워질 것이 없어야 한다.
        // 뿌리는 Caches 그대로 둔다 — 허용 루트 자체라 관문이 막는다.
        let preview = caches.appending(path: "sweep-harness-preview")
        func child(_ name: String, _ size: Int64, _ kids: [DiskUsageNode] = [])
            -> DiskUsageNode {
            DiskUsageNode(url: preview.appending(path: name), size: size, children: kids)
        }
        // 정리 범위 밖(보호됨)과 못 읽는 폴더도 섞는다. 한 상태만 보이면
        // 배지가 실제로 갈라지는지 눈으로 확인할 수 없다.
        let home = FileManager.default.homeDirectoryForCurrentUser
        let outside = DiskUsageNode(
            url: home.appending(path: "Documents/sweep-harness-preview/보호된폴더"),
            size: 2_147_483_648)
        let locked = DiskUsageNode(
            url: home.appending(path: "Documents/sweep-harness-preview/잠긴폴더"),
            size: 0, isReadable: false)

        let model = DiskMapModel()
        model.seed(DiskUsageNode(url: caches, size: 9_663_676_416, children: [
            child("Homebrew", 5_368_709_120, [child("downloads", 4_294_967_296)]),
            outside,
            child("com.apple.dt.Xcode", 1_610_612_736),
            child("org.swift.swiftpm", 419_430_400),
            child("Google", 117_440_512),
            locked,
        ]))
        return model
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
