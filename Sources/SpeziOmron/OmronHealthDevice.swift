//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SpeziDevices


protocol OmronHealthDevice: PairableDevice {}


extension OmronHealthDevice {
    var model: OmronModel {
        OmronModel(deviceInformation.modelNumber ?? "Generic Health Device")
    }

    var manufacturerData: OmronManufacturerData? {
        guard let manufacturerData = advertisementData.manufacturerData else {
            return nil
        }
        return OmronManufacturerData(data: manufacturerData)
    }
}


extension OmronHealthDevice {
    var isInPairingMode: Bool {
        if case .pairingMode = manufacturerData?.pairingMode {
            return true
        }
        return false
    }
}
