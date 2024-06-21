//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import BluetoothServices
import BluetoothViews
import Foundation
import SpeziBluetooth


public protocol GenericDevice: BluetoothDevice, GenericBluetoothPeripheral {
    var id: UUID { get }
    var name: String? { get }
    var advertisementData: AdvertisementData { get }
    var discarded: Bool { get }

    var deviceInformation: DeviceInformationService { get }

    var icon: ImageReference? { get }
}


extension GenericDevice {
    public var label: String {
        name ?? "Generic Device"
    }

    public var icon: ImageReference? {
        nil
    }
}
