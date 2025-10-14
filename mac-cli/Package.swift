// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "vision-subtitle-extractor-mac",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "vision-subtitle-extractor-mac",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "."
        )
    ]
)