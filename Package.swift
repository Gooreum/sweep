// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sweep",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SweepKit", targets: ["SweepKit"]),
        .executable(name: "SweepApp", targets: ["SweepApp"]),
    ],
    targets: [
        .target(name: "SweepKit"),
        .executableTarget(
            name: "SweepApp",
            dependencies: ["SweepKit"],
            // 링커가 직접 읽는다. 리소스로 복사하면 안 되고, 두면 SPM이
            // "처리되지 않은 파일" 경고를 낸다.
            exclude: ["Info.plist"],
            // SPM 실행 파일은 앱 번들이 아니라 Info.plist가 없다. 그래서 메뉴에
            // 실행 파일 이름("SweepApp")이 About/Quit/Help에 그대로 나온다.
            // 바이너리의 __TEXT,__info_plist 섹션에 박으면 번들 없이도 읽힌다.
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/SweepApp/Info.plist",
                ])
            ]),
        .testTarget(name: "SweepKitTests", dependencies: ["SweepKit"]),
    ]
)
