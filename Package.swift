// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VaultCore",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "VaultCore",
            targets: ["VaultCore"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/jedisct1/swift-sodium.git",
            exact: "0.11.0"
        )
    ],
    targets: [
        .target(
            name: "VaultCore",
            dependencies: [
                .product(name: "Sodium", package: "swift-sodium")
            ]
        ),
        .testTarget(
            name: "VaultCoreTests",
            dependencies: ["VaultCore"]
        )
    ]
)
