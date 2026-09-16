import Foundation
import SweepKit

/// App Store 스크린샷용 데모 화면. `--stage store-*`.
///
/// 샌드박스 빌드가 실제로 할 수 있는 것만 보여준다 — `~/Downloads`의 큰 파일·중복 파일,
/// 디스크 맵, 그리고 사용자가 개발 폴더를 허락한 뒤의 Xcode 정리. 캐시·로그·임시 파일은
/// 샌드박스가 막으므로 넣지 않는다. 넣으면 "실제 앱과 다른 스크린샷"으로 반려된다 (App Review 2.3).
///
/// 정크 탭이 Xcode 항목을 받으려면 이 기계에서 개발 폴더가 허락돼 있어야 한다 —
/// 샌드박스에서 정크 파일의 분류는 실제 허락 상태로 정해진다.
@MainActor
enum StoreDemo {

    private static let downloads = Sandbox.userHome
        .appending(path: "Downloads")
    /// 실재하지 않는 폴더. 목록에는 이름만 보이고, 눌러도 지워질 것이 없다.
    private static let preview = downloads.appending(path: "sweep-harness-preview")

    /// 실앱과 같은 흐름으로 채운 `AppModel`.
    /// 스마트 스캔을 한 번 돌리면 `AppModel`이 결과를 기능 탭에 나눠 준다.
    static func app(for stage: String) async -> AppModel {
        let found = items
        let app = AppModel(
            makeModel: { _ in
                ScanModel(scan: { StageHarness.finishing(found) },
                          removeOne: { RemovalOutcome(item: $0, failureReason: nil) })
            },
            makeDiskMap: { diskMap() },
            // 허락한 뒤의 화면을 보여준다
            needsFolderAccess: false)
        await app.model(for: .smartScan).scan()

        switch stage {
        case "store-xcode":
            app.selected = .junk
        case "store-large":
            app.selected = .largeFile
            // 큰 파일은 '주의'라 기본 선택이 없다. 사용자가 몇 개 고른 상태를 보여준다.
            let model = app.model(for: .largeFile)
            for item in model.items.prefix(2) { model.setSelection(true, for: item) }
        case "store-duplicate":
            app.selected = .duplicate
        case "store-diskmap":
            app.selected = .diskMap
        case "store-cleaned":
            app.selected = .duplicate
            await app.model(for: .duplicate).removeSelected()
        default: // store-summary
            app.selected = .smartScan
        }
        return app
    }

    /// 스캐너가 내는 것과 같은 모양 — 큰 파일은 '주의' + "N개월 전에 받았습니다",
    /// 중복은 '안전' + "<원본>와 내용이 같습니다". 카테고리 안에서는 큰 것부터.
    /// 중복은 100MB 미만만 둔다 — 그 이상이면 실앱에서는 큰 파일 쪽이 가져간다(`ScanCoordinator.normalize`).
    private static var items: [CleanupItem] {
        func large(_ name: String, _ size: Int64, _ detail: String) -> CleanupItem {
            CleanupItem(url: preview.appending(path: name), size: size,
                        category: .largeFile, safety: .caution, detail: detail)
        }
        func dup(_ name: String, _ size: Int64, of original: String) -> CleanupItem {
            CleanupItem(url: preview.appending(path: name), size: size,
                        category: .duplicate, safety: .safe,
                        detail: "\(original)와 내용이 같습니다")
        }
        // `XcodeScanner`와 같은 안전도·설명. 목록에는 마지막 경로 이름만 보인다.
        func xcode(_ path: String, _ size: Int64, _ safety: SafetyLevel, _ detail: String)
            -> CleanupItem {
            CleanupItem(url: preview.appending(path: "Library/Developer/\(path)"), size: size,
                        category: .xcode, safety: safety, detail: detail)
        }
        return [
            xcode("Xcode/iOS DeviceSupport/iPhone17,1 26.0 (23A341)", 7_900_000_000,
                  .caution, "기기를 다시 연결하면 내려받습니다"),
            xcode("Xcode/DerivedData/Budgetly-fhbqxkwzpnmxdgaclrviosbtuey", 6_400_000_000,
                  .safe, "빌드하면 다시 생성됩니다"),
            xcode("Xcode/iOS DeviceSupport/iPhone15,2 18.6 (22G86)", 5_800_000_000,
                  .caution, "기기를 다시 연결하면 내려받습니다"),
            xcode("Xcode/DerivedData/PhotoMemo-cgkwzhxeqvnbdjlrtyaoupmsif", 3_100_000_000,
                  .safe, "빌드하면 다시 생성됩니다"),
            xcode("CoreSimulator/Caches", 2_300_000_000, .safe, "시뮬레이터 캐시입니다"),
            xcode("Xcode/DerivedData/ModuleCache.noindex", 1_200_000_000,
                  .safe, "빌드하면 다시 생성됩니다"),
            xcode("Xcode/Archives/2026-08-21", 184_000_000,
                  .danger, "앱 심사 제출본 — 지우면 복구할 수 없습니다"),
            large("Xcode_26.0.xip", 9_800_000_000, "4개월 전에 받았습니다"),
            large("Windows11_ARM64.iso", 6_120_000_000, "7개월 전에 받았습니다"),
            large("제주 여행 원본.mov", 4_210_000_000, "2개월 전에 받았습니다"),
            large("FinalCut 프로젝트 백업.zip", 3_380_000_000, "5개월 전에 받았습니다"),
            large("회의 녹화 0612.mp4", 1_270_000_000, "3개월 전에 받았습니다"),
            large("Docker.dmg", 524_000_000, "1개월 전에 받았습니다"),
            large("Blender-4.2-macos-arm64.dmg", 412_000_000, "12일 전에 받았습니다"),
            dup("Zoom (1).pkg", 91_800_000, of: "Zoom.pkg"),
            dup("KakaoTalk (1).dmg", 74_600_000, of: "KakaoTalk.dmg"),
            dup("발표자료_최종 (1).key", 57_300_000, of: "발표자료_최종.key"),
            dup("2026 사업계획서 (1).pdf", 24_600_000, of: "2026 사업계획서.pdf"),
            dup("2026 사업계획서 (2).pdf", 24_600_000, of: "2026 사업계획서.pdf"),
            dup("IMG_4821 (1).HEIC", 3_100_000, of: "IMG_4821.HEIC"),
        ]
    }

    /// `~/Downloads`를 고른 디스크 맵. Picker가 "선택하세요"가 아니라 "~/Downloads"를 가리킨다.
    private static func diskMap() -> DiskMapModel {
        func node(_ name: String, _ size: Int64, _ kids: [DiskUsageNode] = []) -> DiskUsageNode {
            DiskUsageNode(url: preview.appending(path: name), size: size, children: kids)
        }
        let shoot = preview.appending(path: "촬영본 0612")
        let model = DiskMapModel()
        // seed보다 먼저 넣는다. DiskMapView의 .task가 selectedRoot가 비었을 때만 자동 순회를 건다.
        // Picker 목록의 Downloads와 같은 URL이어야 "선택하세요"로 빠지지 않는다.
        // 샌드박스에서는 그 URL이 컨테이너 링크가 아니라 링크를 푼 경로다.
        let root = DiskMapRoot.all.first { $0.label == "~/Downloads" }?.url ?? downloads
        model.selectedRoot = root
        model.seed(DiskUsageNode(url: root, size: 29_100_000_000, children: [
            node("Xcode_26.0.xip", 9_800_000_000),
            node("Windows11_ARM64.iso", 6_120_000_000),
            node("제주 여행 원본.mov", 4_210_000_000),
            node("FinalCut 프로젝트 백업.zip", 3_380_000_000),
            node("촬영본 0612", 2_740_000_000, [
                DiskUsageNode(url: shoot.appending(path: "A001.mov"), size: 1_600_000_000),
                DiskUsageNode(url: shoot.appending(path: "A002.mov"), size: 1_140_000_000),
            ]),
            node("회의 녹화 0612.mp4", 1_270_000_000),
            node("Docker.dmg", 524_000_000),
            node("Blender-4.2-macos-arm64.dmg", 412_000_000),
            node("스크린샷", 326_000_000),
            node("강의자료", 318_000_000),
        ]))
        return model
    }
}
