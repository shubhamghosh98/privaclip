// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrivaClip",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PrivaClip", targets: ["PrivaClipApp"]),
        .executable(name: "PrivaClipTests", targets: ["PrivaClipCoreTests"]),
        .library(name: "PrivaClipCore", targets: ["PrivaClipCore"]),
        .library(name: "PrivaClipUI", targets: ["PrivaClipUI"])
    ],
    targets: [
        .target(
            name: "PrivaClipCore",
            dependencies: [],
            path: "Sources/PrivaClipCore"
        ),
        .target(
            name: "PrivaClipUI",
            dependencies: ["PrivaClipCore"],
            path: "Sources/PrivaClipUI"
        ),
        .executableTarget(
            name: "PrivaClipApp",
            dependencies: ["PrivaClipCore", "PrivaClipUI"],
            path: "Sources/PrivaClipApp"
        ),
        .executableTarget(
            name: "PrivaClipCoreTests",
            dependencies: ["PrivaClipCore"],
            path: "Tests/PrivaClipCoreTests"
        )
    ]
)
