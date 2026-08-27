// swift-tools-version: 5.9
// SPDX-License-Identifier: MPL-2.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "localhold_key_bridge",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "localhold-key-bridge", targets: ["localhold_key_bridge"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .binaryTarget(
            name: "Clibsodium",
            path: "../Frameworks/Clibsodium.xcframework"
        ),
        .target(
            name: "localhold_key_bridge",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "Clibsodium"
            ],
            resources: [
                .process("Resources/bip39_english.txt"),
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "localhold_key_bridgeTests",
            dependencies: ["localhold_key_bridge"]
        )
    ]
)
