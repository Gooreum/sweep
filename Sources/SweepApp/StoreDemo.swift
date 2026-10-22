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

    /// 화면이 한국어로 떴는가. `-AppleLanguages`로 고른 언어가 그대로 들어온다.
    ///
    /// 파일 이름은 번역할 UI 문구가 아니라 가짜 데이터라 카탈로그에 넣지 않는다.
    /// 다만 영어 스크린샷에 "제주 여행 원본.mov"가 보이면 쓸 수 없어서 언어별로 고른다.
    private static let isKorean = Bundle.main.preferredLocalizations.first == "ko"
    private static func name(_ ko: String, _ en: String) -> String { isKorean ? ko : en }

    // 큰 파일 목록과 디스크 맵이 같은 이름을 보여야 한다.
    private static let tripVideo = name("제주 여행 원본.mov", "Iceland Trip Raw.mov")
    private static let projectBackup = name("FinalCut 프로젝트 백업.zip", "FinalCut Project Backup.zip")
    private static let meetingVideo = name("회의 녹화 0612.mp4", "Team Meeting 0612.mp4")

    /// 스캐너와 **같은 문장**이어야 한다. 데모에서만 다른 문구를 쓰면 영어 스크린샷에 한국어가 남고,
    /// 실제 앱과 다른 화면이 된다.
    private static func daysAgo(_ days: Int) -> String {
        String(localized: "\(days)일 전에 받았어요")
    }

    /// 스캐너와 같은 키 — 카탈로그에 번역이 이미 있고, 영어에서는 복수형까지 맞는다.
    private static func monthsAgo(_ months: Int) -> String {
        String(localized: "\(months)개월 전에 받았어요")
    }

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
            makeCPU: { cpu() },
            projectFolders: projectFolders,
            // 스크린샷용 가짜 삭제가 실제 정리 기록에 쌓이면 안 된다
            history: CleanupHistory(defaults: UserDefaults(suiteName: "sweep-store-demo")!),
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
        case "store-cpu":
            app.selected = .cpu
            app.cpu().select(fileprovider)
        case "store-projects":
            // 이 장면에만 넣는다. 스마트 스캔에 섞으면 1번 스크린샷의 합계(52GB)가 바뀐다.
            app.selected = .projects
            app.model(for: .projects).adopt(projectItems)
        default: // store-summary
            app.selected = .smartScan
        }
        return app
    }

    /// 데모 전용 프로젝트 폴더 목록(`~/Code`). 실제 설정(`ProjectFolders.shared`)을 건드리지 않는다.
    private static let projectFolders: ProjectFolders.Registry = {
        let suite = "sweep-store-demo-projects"
        UserDefaults().removePersistentDomain(forName: suite)
        let registry = ProjectFolders.Registry(defaults: UserDefaults(suiteName: suite)!)
        try? registry.add(Sandbox.userHome.appending(path: "Code"))
        return registry
    }()

    /// 개발 프로젝트 탭의 가짜 결과. `ProjectArtifactScanner`와 같은 안전도·설명이어야 한다 —
    /// 설명은 규칙표의 문구와 스캐너의 주의 문구를 그대로 쓴다(영어 캡처에 한국어가 남지 않게).
    private static var projectItems: [CleanupItem] {
        let code = Sandbox.userHome.appending(path: "Code")
        func hint(_ name: String) -> String {
            ProjectArtifactRule.all.first { $0.name == name }?.rebuildHint ?? ""
        }
        func artifact(_ project: String, _ folder: String, _ size: Int64,
                      _ safety: SafetyLevel = .safe, _ detail: String? = nil) -> CleanupItem {
            CleanupItem(url: code.appending(path: "\(project)/\(folder)"), size: size,
                        category: .projectArtifact, safety: safety, detail: detail ?? hint(folder))
        }
        let recent = String(localized: "최근 \(14)일 안에 고친 프로젝트예요. 지우기 전에 확인해 보세요.")
        let noLock = String(localized: "버전을 고정한 파일이 없어요. 다시 설치하면 버전이 달라질 수 있어요.")
        return [
            artifact("budgetly-web", "node_modules", 1_840_000_000),
            artifact("photo-memo-ios", "Pods", 1_260_000_000),
            artifact("portfolio-site", ".next", 980_000_000),
            artifact("ml-notebooks", ".venv", 2_310_000_000),
            artifact("rust-cli", "target", 3_420_000_000),
            artifact("landing-page", "node_modules", 690_000_000, .caution, recent),
            artifact("admin-dashboard", "node_modules", 1_120_000_000, .caution, noLock),
        ].sorted { $0.size > $1.size }
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
                        detail: String(localized: "이 사본을 지워도 같은 내용은 남아요: \(original)"))
        }
        // `XcodeScanner`와 같은 안전도·설명. 목록에는 마지막 경로 이름만 보인다.
        func xcode(_ path: String, _ size: Int64, _ safety: SafetyLevel, _ detail: String)
            -> CleanupItem {
            CleanupItem(url: preview.appending(path: "Library/Developer/\(path)"), size: size,
                        category: .xcode, safety: safety, detail: detail)
        }
        return [
            xcode("Xcode/iOS DeviceSupport/iPhone17,1 26.0 (23A341)", 7_900_000_000,
                  .caution, String(localized: "iPhone 연결용 파일이에요. Xcode가 다시 받아요")),
            xcode("Xcode/DerivedData/Budgetly-fhbqxkwzpnmxdgaclrviosbtuey", 6_400_000_000,
                  .safe, String(localized: "Xcode가 앱을 만들며 쌓은 중간 결과예요. 지워도 괜찮아요")),
            xcode("Xcode/iOS DeviceSupport/iPhone15,2 18.6 (22G86)", 5_800_000_000,
                  .caution, String(localized: "iPhone 연결용 파일이에요. Xcode가 다시 받아요")),
            xcode("Xcode/DerivedData/PhotoMemo-cgkwzhxeqvnbdjlrtyaoupmsif", 3_100_000_000,
                  .safe, String(localized: "Xcode가 앱을 만들며 쌓은 중간 결과예요. 지워도 괜찮아요")),
            xcode("CoreSimulator/Caches", 2_300_000_000, .safe, String(localized: "가상 기기가 쌓아 둔 파일이에요. 지워도 다시 생겨요")),
            xcode("Xcode/DerivedData/ModuleCache.noindex", 1_200_000_000,
                  .safe, String(localized: "Xcode가 앱을 만들며 쌓은 중간 결과예요. 지워도 괜찮아요")),
            xcode("Xcode/Archives/2026-08-21", 184_000_000,
                  .danger, String(localized: "App Store에 올릴 앱 보관본이에요. 지우면 복구할 수 없어요")),
            large("Xcode_26.0.xip", 9_800_000_000, monthsAgo(4)),
            large("Windows11_ARM64.iso", 6_120_000_000, monthsAgo(7)),
            large(tripVideo, 4_210_000_000, monthsAgo(2)),
            large(projectBackup, 3_380_000_000, monthsAgo(5)),
            large(meetingVideo, 1_270_000_000, monthsAgo(3)),
            large("Docker.dmg", 524_000_000, monthsAgo(1)),
            large("Blender-4.2-macos-arm64.dmg", 412_000_000, daysAgo(12)),
            dup("Zoom (1).pkg", 91_800_000, of: "Zoom.pkg"),
            dup(name("KakaoTalk (1).dmg", "Slack (1).dmg"), 74_600_000,
                of: name("KakaoTalk.dmg", "Slack.dmg")),
            dup(name("발표자료_최종 (1).key", "Pitch Deck Final (1).key"), 57_300_000,
                of: name("발표자료_최종.key", "Pitch Deck Final.key")),
            dup(name("2026 사업계획서 (1).pdf", "2026 Business Plan (1).pdf"), 24_600_000,
                of: name("2026 사업계획서.pdf", "2026 Business Plan.pdf")),
            dup(name("2026 사업계획서 (2).pdf", "2026 Business Plan (2).pdf"), 24_600_000,
                of: name("2026 사업계획서.pdf", "2026 Business Plan.pdf")),
            dup("IMG_4821 (1).HEIC", 3_100_000, of: "IMG_4821.HEIC"),
        ]
    }

    /// `~/Downloads`를 고른 디스크 맵. Picker가 "선택하세요"가 아니라 "~/Downloads"를 가리킨다.
    private static func diskMap() -> DiskMapModel {
        func node(_ name: String, _ size: Int64, _ kids: [DiskUsageNode] = []) -> DiskUsageNode {
            DiskUsageNode(url: preview.appending(path: name), size: size, children: kids)
        }
        let shoot = preview.appending(path: name("촬영본 0612", "Footage 0612"))
        let model = DiskMapModel()
        // seed보다 먼저 넣는다. DiskMapView의 .task가 selectedRoot가 비었을 때만 자동 순회를 건다.
        // Picker 목록의 Downloads와 같은 URL이어야 "선택하세요"로 빠지지 않는다.
        // 샌드박스에서는 그 URL이 컨테이너 링크가 아니라 링크를 푼 경로다.
        let root = DiskMapRoot.all.first { $0.label == "~/Downloads" }?.url ?? downloads
        model.selectedRoot = root
        model.seed(DiskUsageNode(url: root, size: 29_100_000_000, children: [
            node("Xcode_26.0.xip", 9_800_000_000),
            node("Windows11_ARM64.iso", 6_120_000_000),
            node(tripVideo, 4_210_000_000),
            node(projectBackup, 3_380_000_000),
            node(shoot.lastPathComponent, 2_740_000_000, [
                DiskUsageNode(url: shoot.appending(path: "A001.mov"), size: 1_600_000_000),
                DiskUsageNode(url: shoot.appending(path: "A002.mov"), size: 1_140_000_000),
            ]),
            node(meetingVideo, 1_270_000_000),
            node("Docker.dmg", 524_000_000),
            node("Blender-4.2-macos-arm64.dmg", 412_000_000),
            node(name("스크린샷", "Screenshots"), 326_000_000),
            node(name("강의자료", "Course Notes"), 318_000_000),
        ]))
        return model
    }

    // MARK: - CPU 장면

    /// 스크린샷에서 고른 행. 설명·부모·켜진 시간·메모리·명령이 모두 차는 예다.
    private static let fileprovider: pid_t = 3102

    /// 가짜 프로그램. 샌드박스가 읽을 수 있는 **내 계정** 프로그램만 둔다 —
    /// 실제 앱에서 이 칸에 올라올 수 없는 것을 보여주면 "실제 앱과 다른 스크린샷"이다.
    /// 사용률은 코어 하나를 100으로 센다(앱과 같은 기준).
    private static let cpuDemo: [(pid: pid_t, name: String, path: String, percent: Double)] = [
        (2210, "Xcode", "/Applications/Xcode.app/Contents/MacOS/Xcode", 142),
        (4871, "Google Chrome Helper (Renderer)",
         "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/A/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)", 96),
        (5390, "swift-frontend",
         "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-frontend", 71),
        (6644, "node", "/usr/local/bin/node", 38),
        (3920, "Slack", "/Applications/Slack.app/Contents/MacOS/Slack", 12),
        (fileprovider, "fileproviderd",
         "/System/Library/PrivateFrameworks/FileProvider.framework/Support/fileproviderd", 9),
    ]

    /// 스크린샷용 CPU 모델. 누적값을 **흐른 시간에 비례**해 올려서, 몇 번째 주기에 찍어도
    /// 같은 사용률이 나온다. 진짜 프로세스를 읽으면 기계 부하에 따라 숫자가 매번 달라지고,
    /// 이 Mac의 실제 프로그램 이름이 스토어에 나간다.
    static func cpu() -> CPUModel {
        let started = ContinuousClock.now
        @Sendable func seconds() -> Double {
            let elapsed = ContinuousClock.now - started
            return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        }
        let demo = cpuDemo
        let chosen = fileprovider
        return CPUModel(
            cores: 8,
            sample: {
                let now = seconds()
                return demo.map {
                    ProcessCPUTick(pid: $0.pid, name: $0.name, executablePath: $0.path,
                                   nanoseconds: UInt64(now * $0.percent / 100 * 1e9))
                }
            },
            // 기계 전체: 프로그램 40% · Mac 12% · 쉬는 중 48% (초당 1000틱 기준)
            loadSample: {
                let now = seconds()
                return CPULoadTicks(user: UInt32(now * 400), system: UInt32(now * 120),
                                    idle: UInt32(now * 480), nice: 0)
            },
            detailsReader: { pid in
                guard pid == chosen else { return nil }
                return ProcessDetails(
                    pid: pid, name: "fileproviderd", isMine: true,
                    startedAt: Date().addingTimeInterval(-(11 * 86_400 + 11 * 3_600)),
                    launchedBy: [], memoryBytes: 38 * 1_048_576, threads: 9,
                    arguments: ["/System/Library/PrivateFrameworks/FileProvider.framework/Support/fileproviderd"],
                    executablePath: "/System/Library/PrivateFrameworks/FileProvider.framework/Support/fileproviderd")
            })
    }
}
