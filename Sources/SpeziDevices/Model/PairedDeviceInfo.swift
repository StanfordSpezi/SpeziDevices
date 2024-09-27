//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziViews
import SwiftData


/// Persistent information stored of a paired device.
@Model
public final class PairedDeviceInfo {
    /// The CoreBluetooth device identifier.
    @Attribute(.unique) public var id: UUID
    /// The device type.
    ///
    /// Stores the associated ``PairableDevice/deviceTypeIdentifier-9wsed`` device type used to locate the device implementation.
    public var deviceType: String
    /// The last known peripheral name.
    public var peripheralName: String?
    /// A model string of the device.
    public var model: String?

    /// The user edit-able name of the device.
    public internal(set) var name: String
    /// The date the device was last seen.
    public internal(set) var lastSeen: Date
    /// The last reported battery percentage of the device.
    public internal(set) var lastBatteryPercentage: UInt8?

    /// The date at which the device was paired.
    public internal(set) var pairedAt: Date
    
    /// Defines the variant of the bluetooth device.
    ///
    /// A bluetooth device might implement the logic for multiple device variants that each have a different appearance. In these cases the device can define a appearance for each variant.
    /// This identifier stores the variant identifier of the variant we observed upon pairing.
    public internal(set) var variantIdentifier: String? // TODO: observable? create legacy data store tests!

    /// Could not retrieve the device from the Bluetooth central.
    @Transient public internal(set) var notLocatable: Bool = false
    @Transient private var _icon: ImageReference?

    /// Visual representation of the device.
    public var icon: ImageReference? {
        get {
            _$observationRegistrar.access(self, keyPath: \.icon)
            return _icon
        }
        set {
            _$observationRegistrar.withMutation(of: self, keyPath: \.icon) {
                _icon = newValue
            }
        }
    }

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
        icon: ImageReference? = nil,
        variantIdentifier: String? = nil,
        lastSeen: Date = .now,
        batteryPercentage: UInt8? = nil
    ) {
        self.id = id
        self.deviceType = deviceType
        self.name = name
        self.peripheralName = name
        self.model = model
        self._icon = icon
        self.variantIdentifier = variantIdentifier
        self.lastSeen = lastSeen
        self.lastBatteryPercentage = batteryPercentage

        self.pairedAt = .now
    }
}


extension PairedDeviceInfo: Identifiable {}


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


extension PairedDeviceInfo: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        """
        PairedDeviceInfo(
        id: \(id), \
        deviceType: \(deviceType), \
        peripheralName: \(peripheralName.map { $0.description } ?? "nil"), \
        model: \(model.map { $0.description } ?? "nil"), \
        name: \(name), \
        lastSeen: \(lastSeen), \
        lastBatteryPercentage: \(lastBatteryPercentage.map { $0.description } ?? "nil"), \
        pairedAt: \(pairedAt), \
        variantIdentifier: \(variantIdentifier.map { $0.description } ?? "nil"), \
        notLocatable: \(notLocatable), \
        icon: \(_icon.map { "\($0)" } ?? "nil")\
        )
        """
    }

    public var debugDescription: String {
        description
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
