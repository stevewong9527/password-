// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VaultCore",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "VaultCore", targets: ["VaultCore"]),
        .library(name: "VaultAppCore", targets: ["VaultAppCore"])
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
        .target(
            name: "VaultAppCore",
            dependencies: ["VaultCore"]
        ),
        .testTarget(
            name: "VaultCoreTests",
            dependencies: ["VaultCore"]
        ),
        .testTarget(
            name: "VaultAppCoreTests",
            dependencies: ["VaultAppCore"]
        )
    ]
)
