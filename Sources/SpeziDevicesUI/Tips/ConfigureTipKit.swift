//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
@_spi(TestingSupport) import SpeziFoundation
import TipKit


class ConfigureTipKit: Module, DefaultInitializable { // TODO: move to SpeziViews!
    @Application(\.logger) private var logger


    required init() {}

    func configure() {
        if RuntimeConfig.testingTips || ProcessInfo.processInfo.isPreviewSimulator {
            Tips.showAllTipsForTesting()
        }
        do {
            try Tips.configure()
        } catch {
            Self.logger.error("Failed to configure TipKit: \(error)")
        }
    }
}


extension RuntimeConfig {
    /// Enable testing tips
    static let testingTips = CommandLine.arguments.contains("--testTips")
}
