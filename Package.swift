// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SubtitleExtractor",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SubtitleExtractor",
            dependencies: [],
            path: "."
        )
    ]
)