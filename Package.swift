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
        .executableTarget(name: "SweepApp", dependencies: ["SweepKit"]),
        .testTarget(name: "SweepKitTests", dependencies: ["SweepKit"]),
    ]
)
