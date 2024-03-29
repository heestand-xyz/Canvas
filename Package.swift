// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Canvas",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Canvas",
            targets: ["Canvas"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/MultiViews", from: "2.1.0"),
        .package(url: "https://github.com/heestand-xyz/CoreGraphicsExtensions", from: "1.5.0"),
        .package(url: "https://github.com/heestand-xyz/DisplayLink", from: "1.0.5"),
        .package(url: "https://github.com/heestand-xyz/Logger", from: "0.3.1"),
    ],
    targets: [
        .target(
            name: "Canvas",
            dependencies: ["MultiViews", "CoreGraphicsExtensions", "DisplayLink", "Logger"]),
      ]
)
