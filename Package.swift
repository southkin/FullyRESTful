// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FullyRESTful",
    platforms: [
        .iOS(.v13),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "FullyRESTful",
            targets: ["FullyRESTful"]),
    ],
    dependencies: [
        .package(url: "https://github.com/southkin/KinKit", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "FullyRESTful",
            dependencies: [
                .product(name: "KinKit", package: "KinKit"),
            ]
        ),
        .testTarget(
            name: "FullyRESTfulTests",
            dependencies: ["FullyRESTful"])
    ]
)
