//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import HealthKit


extension HealthDevice {
    public var hkDevice: HKDevice { // TODO: doesn't necessarily need to be public if we move MeasurementManager!
        HKDevice(
            name: name,
            manufacturer: deviceInformation.manufacturerName,
            model: deviceInformation.modelNumber,
            hardwareVersion: deviceInformation.hardwareRevision,
            firmwareVersion: deviceInformation.firmwareRevision,
            softwareVersion: deviceInformation.softwareRevision,
            localIdentifier: nil,
            udiDeviceIdentifier: nil
        )
    }
}
