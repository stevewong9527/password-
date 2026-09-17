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
        ),
        .library(
            name: "VaultCrypto",
            targets: ["VaultCrypto"]
        )
    ],
    targets: [
        .target(
            name: "VaultCore"
        ),
        .target(
            name: "VaultCrypto",
            dependencies: ["VaultCore"]
        ),
        .testTarget(
            name: "VaultCoreTests",
            dependencies: ["VaultCore"]
        ),
        .testTarget(
            name: "VaultCryptoTests",
            dependencies: ["VaultCore", "VaultCrypto"]
        )
    ]
)
