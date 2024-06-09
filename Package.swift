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
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .tvOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SpeziOmron", targets: ["SpeziOmron"])
    ],
    targets: [
        .target(
            name: "SpeziOmron"
        ),
        .testTarget(
            name: "SpeziOmronTests",
            dependencies: [
                .target(name: "SpeziOmron")
            ]
        )
    ]
)
