//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//


public struct OmronModel: RawRepresentable {
    public let rawValue: String

    public init(_ model: String) {
        self.init(rawValue: model)
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}


extension OmronModel {
    /// The Omron SC150 weight scale.
    public static let sc150 = OmronModel("SC-150")
    /// The Omron BP5250 blood pressure monitor.
    public static let bp5250 = OmronModel("BP5250")
}


extension OmronModel: Codable {
    public init(from decoder: any Decoder) throws {
        let decoder = try decoder.singleValueContainer()
        self.rawValue = try decoder.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var encoder = encoder.singleValueContainer()
        try encoder.encode(rawValue)
    }
}
