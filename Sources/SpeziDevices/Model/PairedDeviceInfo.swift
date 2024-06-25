//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Persistent information stored of a paired device.
@Observable
public class PairedDeviceInfo {
    /// The CoreBluetooth device identifier.
    public let id: UUID
    /// The device type.
    ///
    /// Stores the associated ``PairableDevice/deviceTypeIdentifier-9wsed`` device type used to locate the device implementation.
    public let deviceType: String
    /// Visual representation of the device.
    public let icon: ImageReference?
    /// A model string of the device.
    public let model: String?

    /// The user edit-able name of the device.
    public internal(set) var name: String
    /// The date the device was last seen.
    public internal(set) var lastSeen: Date
    /// The last reported battery percentage of the device.
    public internal(set) var lastBatteryPercentage: UInt8?
    public internal(set) var notLocatable: Bool = false // TODO: update name // TODO: docs

    /// Create new paired device information.
    /// - Parameters:
    ///   - id: The CoreBluetooth device identifier
    ///   - deviceType: The device type.
    ///   - name: The device name.
    ///   - model: A model string.
    ///   - icon: The device icon.
    ///   - lastSeen: The date the device was last seen.
    ///   - batteryPercentage: The last known battery percentage of the device.
    public init(
        id: UUID,
        deviceType: String,
        name: String,
        model: String?,
        icon: ImageReference?,
        lastSeen: Date = .now,
        batteryPercentage: UInt8? = nil
    ) {
        self.id = id
        self.deviceType = deviceType
        self.name = name
        self.model = model
        self.icon = icon
        self.lastSeen = lastSeen
        self.lastBatteryPercentage = batteryPercentage
    }

    /// Initialize from decoder.
    public required convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            deviceType: container.decode(String.self, forKey: .deviceType),
            name: container.decode(String.self, forKey: .name),
            model: container.decodeIfPresent(String.self, forKey: .name),
            icon: container.decodeIfPresent(ImageReference.self, forKey: .icon),
            lastSeen: container.decode(Date.self, forKey: .lastSeen),
            batteryPercentage: container.decodeIfPresent(UInt8.self, forKey: .batteryPercentage)
        )
    }
}


extension PairedDeviceInfo: Identifiable, Codable {
    fileprivate enum CodingKeys: String, CodingKey {
        case id
        case deviceType
        case name
        case model
        case icon
        case lastSeen
        case batteryPercentage
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(deviceType, forKey: .deviceType)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(lastSeen, forKey: .lastSeen)
        try container.encodeIfPresent(lastBatteryPercentage, forKey: .batteryPercentage)
    }
}


extension PairedDeviceInfo: Hashable {
    public static func == (lhs: PairedDeviceInfo, rhs: PairedDeviceInfo) -> Bool {
        lhs.id == rhs.id
            && lhs.deviceType == rhs.deviceType
            && lhs.name == rhs.name
            && lhs.model == rhs.model
            && lhs.icon == rhs.icon
            && lhs.lastSeen == rhs.lastSeen
            && lhs.lastBatteryPercentage == rhs.lastBatteryPercentage
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


#if DEBUG
extension PairedDeviceInfo {
    /// Mock Health Device 1 Data.
    @_spi(TestingSupport) public static var mockHealthDevice1: PairedDeviceInfo {
        PairedDeviceInfo(
            id: UUID(),
            deviceType: "HealthDevice1",
            name: "Health Device 1",
            model: "HD1",
            icon: nil
        )
    }

    /// Mock Health Device 2 Data.
    @_spi(TestingSupport) public static var mockHealthDevice2: PairedDeviceInfo {
        PairedDeviceInfo(
            id: UUID(),
            deviceType: "HealthDevice2",
            name: "Health Device 2",
            model: "HD2",
            icon: nil
        )
    }
}
#endif
