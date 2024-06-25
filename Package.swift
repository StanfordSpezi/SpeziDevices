// swift-tools-version:5.9

//
// This source file is part of the Stanford SpeziDevices open source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import PackageDescription

// TODO: DOI in citation.cff


let package = Package(
    name: "SpeziDevices",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SpeziDevices", targets: ["SpeziDevices"]),
        .library(name: "SpeziDevicesUI", targets: ["SpeziDevicesUI"]),
        .library(name: "SpeziOmron", targets: ["SpeziOmron"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.1"),
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation", from: "1.1.1"),
        .package(url: "https://github.com/StanfordSpezi/SpeziViews.git", branch: "feature/configure-tipkit-module"),
        .package(url: "https://github.com/StanfordSpezi/SpeziBluetooth", branch: "feature/accessory-discovery"),
        .package(url: "https://github.com/StanfordSpezi/SpeziNetworking", from: "2.0.0"),
        .package(url: "https://github.com/JWAutumn/ACarousel", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/realm/SwiftLint.git", .upToNextMinor(from: "0.55.1"))
    ],
    targets: [
        .target(
            name: "SpeziDevices",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "SpeziFoundation", package: "SpeziFoundation"),
                .product(name: "SpeziBluetooth", package: "SpeziBluetooth"),
                .product(name: "SpeziBluetoothServices", package: "SpeziBluetooth"),
                .product(name: "SpeziViews", package: "SpeziViews")
            ],
            plugins: [.swiftLintPlugin]
        ),
        .target(
            name: "SpeziDevicesUI",
            dependencies: [
                .target(name: "SpeziDevices"),
                .product(name: "SpeziViews", package: "SpeziViews"),
                .product(name: "SpeziValidation", package: "SpeziViews"),
                .product(name: "SpeziBluetooth", package: "SpeziBluetooth"),
                .product(name: "ACarousel", package: "ACarousel")
            ],
            resources: [
                .process("Resources")
            ],
            plugins: [.swiftLintPlugin]
        ),
        .target(
            name: "SpeziOmron",
            dependencies: [
                .target(name: "SpeziDevices"),
                .product(name: "SpeziBluetooth", package: "SpeziBluetooth"),
                .product(name: "SpeziBluetoothServices", package: "SpeziBluetooth")
            ],
            plugins: [.swiftLintPlugin]
        ),
        .testTarget(
            name: "SpeziDevicesTests",
            dependencies: [
                .target(name: "SpeziDevices")
            ],
            plugins: [.swiftLintPlugin]
        ),
        .testTarget(
            name: "SpeziOmronTests",
            dependencies: [
                .target(name: "SpeziOmron"),
                .product(name: "SpeziBluetooth", package: "SpeziBluetooth"),
                .product(name: "XCTByteCoding", package: "SpeziNetworking")
            ],
            plugins: [.swiftLintPlugin]
        )
    ]
)


extension Target.PluginUsage {
    static var swiftLintPlugin: Target.PluginUsage {
        .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")
    }
}
