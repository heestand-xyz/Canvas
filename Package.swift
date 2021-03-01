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
        .package(url: "https://github.com/heestand-xyz/MultiViews", from: "1.3.1"),
        .package(url: "https://github.com/heestand-xyz/CoreGraphicsExtensions", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "Canvas",
            dependencies: ["MultiViews", "CoreGraphicsExtensions"]),
      ]
)
