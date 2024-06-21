//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Persistent information stored of a paired device.
public struct PairedDeviceInfo {
    // TODO: observablen => resolves UI update issue!
    // TODO: update properties (model, lastSeen, battery) with Observation framework and not via explicit calls in the device class
    //  => make some things have internal setters(?)
    // TODO: additionalData: lastSequenceNumber: UInt16?, userDatabaseNumber: UInt32?, consentCode: UIntX

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
    public var name: String
    /// The date the device was last seen.
    public var lastSeen: Date
    /// The last reported battery percentage of the device.
    public var lastBatteryPercentage: UInt8?

    // TODO: how with codability? public var additionalData: [String: Any]

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
}


extension PairedDeviceInfo: Identifiable, Codable {}


extension PairedDeviceInfo: Hashable {
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
