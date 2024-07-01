//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziBluetooth
import SpeziBluetoothServices


/// A generic Bluetooth device.
///
/// A generic Bluetooth device that provides access to basic device information.
public protocol GenericDevice: BluetoothDevice, GenericBluetoothPeripheral, Identifiable {
    /// An icon that is used to visually present the device to the user.
    static var icon: ImageReference? { get }

    /// The device identifier.
    ///
    /// Use the [`DeviceState`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/devicestate) property wrapper to
    /// declare this property.
    /// ```swift
    /// @DeviceState(\.id) var id
    /// ```
    var id: UUID { get }

    /// The device name.
    ///
    /// Use the [`DeviceState`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/devicestate) property wrapper to
    /// declare this property.
    /// ```swift
    /// @DeviceState(\.name) var name
    /// ```
    var name: String? { get }

    /// The advertisement data received in the latest advertisement.
    ///
    /// Use the [`DeviceState`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/devicestate) property wrapper to
    /// declare this property.
    /// ```swift
    /// @DeviceState(\.advertisementData) var advertisementData
    /// ```
    var advertisementData: AdvertisementData { get }

    /// The device information service of the peripheral.
    ///
    /// Use the [`@Service`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/service) property wrapper to
    /// declare this property.
    /// ```swift
    /// @Service var deviceInformation = DeviceInformationService()
    /// ```
    var deviceInformation: DeviceInformationService { get }
}


extension GenericDevice {
    /// Default icon implementation.
    ///
    /// Returns `nil` by default. Results in a generic icon to be presented.
    public static var icon: ImageReference? {
        nil
    }

    /// Default label implementation.
    ///
    /// Returns `"Generic Device"` if the peripheral doesn't expose a ``name``.
    public var label: String {
        name ?? "Generic Device"
    }
}
