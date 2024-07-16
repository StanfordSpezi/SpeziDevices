//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//


/// Omron Model.
public struct OmronModel {
    /// The raw model number.
    public let rawValue: String

    /// Initialize from raw value.
    /// - Parameter rawValue: The raw model number string.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}


extension OmronModel {
    /// The Omron SC150 weight scale.
    public static let sc150 = OmronModel(rawValue: "SC-150")
    /// The Omron BP5250 blood pressure monitor.
    public static let bp5250 = OmronModel(rawValue: "BP5250")
}


extension OmronModel: RawRepresentable {}


extension OmronModel: Hashable, Sendable {}


extension OmronModel: Codable {}
