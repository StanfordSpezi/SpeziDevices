//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Persistent information stored of a paired device.
public struct PairedDeviceInfo { // TODO: observablen => resolves UI update issue!
    /// The CoreBluetooth device identifier.
    public let id: UUID
    /// The device type.
    ///
    /// Stores the associated ``PairableDevice/deviceTypeIdentifier-9wsed`` device type used to locate the device implementation.
    public let deviceType: String // TODO: verify link
    /// Visual representation of the device.
    public let icon: ImageReference?
    /// A model string of the device.
    public let model: String? // TODO: this one as well!

    // TODO: make some things have internal setters?
    /// The user edit-able name of the device.
    public var name: String
    /// The date the device was last seen.
    public var lastSeen: Date // TODO: don't set within the device class itself
    /// The last reported battery percentage of the device.
    public var lastBatteryPercentage: UInt8? // TODO: update those values based on the Observation framework?


    public var lastSequenceNumber: UInt16?
    public var userDatabaseNumber: UInt32? // TODO: default value?
    // TODO: consent code?
    // TODO: last transfer time?
    // TODO: handle extensibility?

    /// Create new paired device information.
    /// - Parameters:
    ///   - id: The CoreBluetooth device identifier
    ///   - deviceType: The device type.
    ///   - name: The device name.
    ///   - model: A model string.
    ///   - icon: The device icon.
    ///   - lastSeen: The date the device was last seen.
    ///   - batteryPercentage: The last known battery percentage of the device.
    ///   - lastSequenceNumber: // TODO: docs
    ///   - userDatabaseNumber: // TODO: docs
    public init(
        id: UUID,
        deviceType: String,
        name: String,
        model: String?,
        icon: ImageReference?,
        lastSeen: Date = .now,
        batteryPercentage: UInt8? = nil,
        lastSequenceNumber: UInt16? = nil,
        userDatabaseNumber: UInt32? = nil
    ) {
        self.id = id
        self.deviceType = deviceType
        self.name = name
        self.model = model
        self.icon = icon
        self.lastSeen = lastSeen
        self.lastBatteryPercentage = batteryPercentage
        self.lastSequenceNumber = lastSequenceNumber
        self.userDatabaseNumber = userDatabaseNumber
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
    /*
     // TODO: bring back those???
    static var mockBP5250: PairedDeviceInfo {
        PairedDeviceInfo(
            id: UUID(),
            deviceType: BloodPressureCuffDevice.deviceTypeIdentifier,
            name: "BP5250",
            model: OmronModel.bp5250,
            icon: .asset("Omron-BP5250")
        )
    }

    static var mockSC150: PairedDeviceInfo {
        PairedDeviceInfo(
            id: UUID(),
            deviceType: WeightScaleDevice.deviceTypeIdentifier,
            name: "SC-150",
            model: OmronModel.sc150,
            icon: .asset("Omron-SC-150")
        )
    }
    */

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
