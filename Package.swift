// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Muxia",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MuxiaCore", targets: ["MuxiaCore"])
    ],
    targets: [
        .target(
            name: "MuxiaCore",
            path: "Sources/MuxiaCore"
        ),
        .testTarget(
            name: "MuxiaCoreTests",
            dependencies: ["MuxiaCore"],
            path: "Tests/MuxiaCoreTests"
        )
    ]
)
