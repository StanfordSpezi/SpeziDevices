// swift-tools-version:5.9

//
// This source file is part of the Stanford SpeziDevices open source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import class Foundation.ProcessInfo
import PackageDescription


#if swift(<6)
let swiftConcurrency: SwiftSetting = .enableExperimentalFeature("SwiftConcurrency")
#else
let swiftConcurrency: SwiftSetting = .enableUpcomingFeature("SwiftConcurrency")
#endif


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
        .package(url: "https://github.com/StanfordSpezi/Spezi.git", from: "1.4.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziViews.git", from: "1.5.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziBluetooth", from: "2.0.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziNetworking", branch: "feature/raw-representable"),
        .package(url: "https://github.com/StanfordBDHG/XCTestExtensions.git", .upToNextMinor(from: "0.4.11"))
    ] + swiftLintPackage(),
    targets: [
        .target(
            name: "SpeziDevices",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "SpeziFoundation", package: "SpeziFoundation"),
                .product(name: "SpeziBluetooth", package: "SpeziBluetooth"),
                .product(name: "SpeziBluetoothServices", package: "SpeziBluetooth"),
                .product(name: "SpeziViews", package: "SpeziViews"),
                .product(name: "Spezi", package: "Spezi")
            ],
            swiftSettings: [
                swiftConcurrency
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .target(
            name: "SpeziDevicesUI",
            dependencies: [
                .target(name: "SpeziDevices"),
                .product(name: "SpeziViews", package: "SpeziViews"),
                .product(name: "SpeziValidation", package: "SpeziViews"),
                .product(name: "SpeziBluetooth", package: "SpeziBluetooth")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                swiftConcurrency
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .target(
            name: "SpeziOmron",
            dependencies: [
                .target(name: "SpeziDevices"),
                .product(name: "SpeziBluetooth", package: "SpeziBluetooth"),
                .product(name: "SpeziBluetoothServices", package: "SpeziBluetooth")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                swiftConcurrency
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "SpeziDevicesTests",
            dependencies: [
                .target(name: "SpeziDevices"),
                .product(name: "SpeziFoundation", package: "SpeziFoundation"),
                .product(name: "XCTSpezi", package: "Spezi"),
                .product(name: "SpeziBluetooth", package: "SpeziBluetooth"),
                .product(name: "SpeziBluetoothServices", package: "SpeziBluetooth"),
                .product(name: "XCTestExtensions", package: "XCTestExtensions")
            ],
            swiftSettings: [
                swiftConcurrency
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "SpeziOmronTests",
            dependencies: [
                .target(name: "SpeziOmron"),
                .product(name: "SpeziBluetooth", package: "SpeziBluetooth"),
                .product(name: "XCTByteCoding", package: "SpeziNetworking"),
                .product(name: "XCTestExtensions", package: "XCTestExtensions")
            ],
            swiftSettings: [
                swiftConcurrency
            ],
            plugins: [] + swiftLintPlugin()
        )
    ]
)


func swiftLintPlugin() -> [Target.PluginUsage] {
    // Fully quit Xcode and open again with `open --env SPEZI_DEVELOPMENT_SWIFTLINT /Applications/Xcode.app`
    if ProcessInfo.processInfo.environment["SPEZI_DEVELOPMENT_SWIFTLINT"] != nil {
        [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
    } else {
        []
    }
}

func swiftLintPackage() -> [PackageDescription.Package.Dependency] {
    if ProcessInfo.processInfo.environment["SPEZI_DEVELOPMENT_SWIFTLINT"] != nil {
        [.package(url: "https://github.com/realm/SwiftLint.git", .upToNextMinor(from: "0.55.1"))]
    } else {
        []
    }
}
