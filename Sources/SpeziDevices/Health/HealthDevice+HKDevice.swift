//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import HealthKit


extension HealthDevice {
    /// The HealthKit Device description.
    public var hkDevice: HKDevice {
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
