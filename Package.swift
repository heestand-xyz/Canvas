// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Canvas",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Canvas",
            targets: ["Canvas"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/MultiViews", from: "3.0.0"),
        .package(url: "https://github.com/heestand-xyz/CoreGraphicsExtensions", from: "2.0.0"),
        .package(url: "https://github.com/heestand-xyz/DisplayLink", from: "2.0.0"),
        .package(url: "https://github.com/heestand-xyz/Logger", from: "0.3.1"),
    ],
    targets: [
        .target(
            name: "Canvas",
            dependencies: ["MultiViews", "CoreGraphicsExtensions", "DisplayLink", "Logger"]),
      ]
)
