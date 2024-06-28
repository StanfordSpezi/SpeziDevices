//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//


import HealthKit
import SwiftData


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

private struct CodableHKQuantitySample {

}


@Model
final class StoredMeasurement {
    @Attribute(.unique) var associatedMeasurement: UUID
    let measurement: SwiftDataBluetoothHealthMeasurementWorkaroundContainer
    fileprivate let codableDevice: CodableHKDevice

    var device: HKDevice {
        codableDevice.hkDevice
    }

    init(associatedMeasurement: UUID, measurement: SwiftDataBluetoothHealthMeasurementWorkaroundContainer, device: HKDevice) {
        self.associatedMeasurement = associatedMeasurement
        self.measurement = measurement
        self.codableDevice = CodableHKDevice(from: device)
    }
}


extension CodableHKDevice: Codable {}


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


/*
extension CodableHKQuantitySample {
    var hkSample: HKQuantitySample {
        HKQuantitySample(
            type: <#T##HKQuantityType#>,
            quantity: <#T##HKQuantity#>,
            start: <#T##Date#>,
            end: <#T##Date#>,
            device: <#T##HKDevice?#>,
            metadata: <#T##[String : Any]?#>
        )
    }
}*/
