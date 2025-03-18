// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FullyRESTful",
    platforms: [
        .iOS(.v13),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "FullyRESTful",
            targets: ["FullyRESTful"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "FullyRESTful"),
        .testTarget(
            name: "FullyRESTfulTests",
            dependencies: ["FullyRESTful"])
    ]
)
