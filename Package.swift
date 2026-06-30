// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ObsidianTodoBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ObsidianTodoBar",
            path: "Sources/ObsidianTodoBar",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
