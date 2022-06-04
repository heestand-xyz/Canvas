// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Canvas",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "Canvas",
            targets: ["Canvas"]),
    ],
    dependencies: [
        .package(url: "https://github.com/heestand-xyz/MultiViews", from: "1.5.0"),
        .package(url: "https://github.com/heestand-xyz/CoreGraphicsExtensions", from: "1.2.1"),
        .package(url: "https://github.com/heestand-xyz/DisplayLink", from: "1.0.2"),
        .package(url: "https://github.com/heestand-xyz/Logger", from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "Canvas",
            dependencies: ["MultiViews", "CoreGraphicsExtensions", "DisplayLink", "Logger"]),
      ]
)
