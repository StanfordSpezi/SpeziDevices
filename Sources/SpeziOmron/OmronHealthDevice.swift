//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SpeziDevices


/// An Omron Health Device.
///
/// An Omron Health Device is a `HealthDevice` that is pairable.
/// Further, it might adopt the `BatteryPoweredDevice` protocol if the Omron device supports the battery service.
public protocol OmronHealthDevice: HealthDevice, PairableDevice {}


extension OmronHealthDevice {
    /// The Omron model string.
    public var model: OmronModel {
        OmronModel(deviceInformation.modelNumber ?? "Generic Health Device")
    }

    /// The Omron Manufacturer data observed in the Bluetooth advertisement.
    public var manufacturerData: OmronManufacturerData? {
        guard let manufacturerData = advertisementData.manufacturerData else {
            return nil
        }
        return OmronManufacturerData(data: manufacturerData)
    }
}


extension OmronHealthDevice {
    /// Default implementation determining if device is in pairing mode.
    ///
    /// Pairing mode is advertised by the device through the ``manufacturerData`` in the Bluetooth advertisement.
    public var isInPairingMode: Bool {
        if case .pairingMode = manufacturerData?.pairingMode {
            return true
        }
        return false
    }
}
