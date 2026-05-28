// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AudioPlayerClient",
    platforms: [
        .iOS(.v17), .macOS(.v14),
    ],
    products: [
        .singleTargetLibrary("AudioPlayerClient"),
        .singleTargetLibrary("AudioPlayerClientLive"),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture.git",
            from: "1.25.5"
        ),
    ],
    targets: [
        .target(
            name: "AudioPlayerClient",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "AudioPlayerClientLive",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "AudioPlayerClient",
            ]
        ),
        .testTarget(
            name: "AudioPlayerClientTests",
            dependencies: ["AudioPlayerClient"]
        ),
    ]
)

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}
