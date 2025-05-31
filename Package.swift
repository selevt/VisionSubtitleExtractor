// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "VisionSubtitleExtractor",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VisionSubtitleExtractor",
            dependencies: [],
            path: "."
        )
    ]
)