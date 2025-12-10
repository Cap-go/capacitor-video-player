// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorVideoPlayer",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "CapgoCapacitorVideoPlayer",
            targets: ["VideoPlayerPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "VideoPlayerPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/VideoPlayerPlugin"),
        .testTarget(
            name: "VideoPlayerPluginTests",
            dependencies: ["VideoPlayerPlugin"],
            path: "ios/Tests/VideoPlayerPluginTests")
    ]
)
