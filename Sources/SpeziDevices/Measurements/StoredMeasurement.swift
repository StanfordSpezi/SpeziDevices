//
// This source file is part of the ENGAGE-HF project based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//


import HealthKit


private struct CodableHKDevice {
    let name: String?
    let manufacturer: String?
    let model: String?
    let hardwareVersion: String?
    let firmwareVersion: String?
    let softwareVersion: String?
    let localIdentifier: String?
    let udiDeviceIdentifier: String?
}


struct StoredMeasurement {
    let measurement: BluetoothHealthMeasurement
    fileprivate let codableDevice: CodableHKDevice

    var device: HKDevice {
        codableDevice.hkDevice
    }

    init(measurement: BluetoothHealthMeasurement, device: HKDevice) {
        self.measurement = measurement
        self.codableDevice = CodableHKDevice(from: device)
    }
}


extension CodableHKDevice: Codable {}

extension StoredMeasurement: Codable {
    private enum CodingKeys: String, CodingKey {
        case measurement
        case codableDevice = "device"
    }
}


extension CodableHKDevice {
    var hkDevice: HKDevice {
        HKDevice(
            name: name,
            manufacturer: manufacturer,
            model: model,
            hardwareVersion: hardwareVersion,
            firmwareVersion: firmwareVersion,
            softwareVersion: softwareVersion,
            localIdentifier: localIdentifier,
            udiDeviceIdentifier: udiDeviceIdentifier
        )
    }

    init(from hkDevice: HKDevice) {
        self.name = hkDevice.name
        self.manufacturer = hkDevice.manufacturer
        self.model = hkDevice.model
        self.hardwareVersion = hkDevice.hardwareVersion
        self.firmwareVersion = hkDevice.firmwareVersion
        self.softwareVersion = hkDevice.softwareVersion
        self.localIdentifier = hkDevice.localIdentifier
        self.udiDeviceIdentifier = hkDevice.udiDeviceIdentifier
    }
}
