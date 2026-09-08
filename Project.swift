//
//  App Store 제출용 Xcode 프로젝트 매니페스트.
//
//  SPM은 앱 번들을 못 만들고 `xcodebuild archive`를 걸 대상도 못 준다.
//  직접 배포(`scripts/make-app.sh`)는 SPM 산출물을 손으로 감싸 해결했지만,
//  App Store는 Organizer가 읽을 `.xcarchive`를 요구한다.
//
//  `.gitignore`가 `*.xcodeproj`를 무시한다 — 프로젝트는 생성물이고
//  이 파일이 원본이다. 만들기: `bash scripts/make-archive.sh`
//
//  SPM을 로컬 패키지로 끌어들이지 않고 타겟을 직접 정의한다.
//  `Package.swift`의 SweepApp 타겟은 `.unsafeFlags`로 링커에 Info.plist를
//  박는데, 그건 번들이 없는 SPM 실행 파일용 우회다. 여기서는 진짜
//  `Contents/Info.plist`가 들어가므로 필요 없고, 패키지 의존성으로 끌면
//  그 unsafeFlags가 따라온다.
//
import ProjectDescription

let project = Project(
    name: "Sweep",
    targets: [
        .target(
            name: "SweepKit",
            destinations: .macOS,
            // 정적이라 앱 안에 Frameworks 디렉토리가 생기지 않는다.
            // 임베드·재서명 대상이 하나 줄고 App Store 검증도 단순해진다.
            product: .staticFramework,
            bundleId: "com.gooreum.SweepKit",
            deploymentTargets: .macOS("14.0"),
            sources: ["Sources/SweepKit/**"]
        ),
        .target(
            name: "Sweep",
            destinations: .macOS,
            product: .app,
            bundleId: "com.gooreum.sweep",
            deploymentTargets: .macOS("14.0"),
            // 버전 출처를 하나로 유지한다. 여기서 다시 적으면 직접 배포본과
            // App Store 빌드의 버전이 조용히 갈린다.
            infoPlist: .file(path: "Sources/SweepApp/Info.plist"),
            // `**`가 아니라 `*.swift`다. 같은 디렉토리의 Info.plist·entitlements가
            // 리소스로 딸려 들어가면 번들에 중복으로 박힌다.
            sources: ["Sources/SweepApp/*.swift"],
            // `scripts/make-icon.swift --appiconset`이 만든다. 저장소에는 없다.
            resources: ["Resources/Assets.xcassets"],
            entitlements: .file(path: "Sources/SweepApp/Sweep.entitlements"),
            dependencies: [.target(name: "SweepKit")]
        ),
    ]
)
