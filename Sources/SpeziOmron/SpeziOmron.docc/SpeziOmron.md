# ``SpeziOmron``

Support interactions with Omron Bluetooth Devices.

<!--
#
# This source file is part of the Stanford SpeziDevices open source project
#
# SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
#
# SPDX-License-Identifier: MIT
#
-->

## Overview

SpeziOmron extends SpeziDevices with support for Omron devices. This includes Omron-specific models, characteristics, services and fully reusable
device support.

### Omron Devices

The ``OmronBloodPressureCuff`` and ``OmronWeightScale``
devices provide reusable device implementations for Omron blood pressure cuffs
and the Omron weight scales respectively.
Both devices automatically integrate with the [`HealthMeasurements`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/healthmeasurements)
and [`PairedDevices`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/paireddevices) modules of SpeziDevices.
You just need to configure them for use with the [`Bluetooth`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth#Configure-the-Bluetooth-Module)
module.

```swift
import SpeziBluetooth
import SpeziBluetoothServices
import SpeziDevices
import SpeziOmron

class ExampleAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth {
                Discover(OmronBloodPressureCuff.self, by: .accessory(manufacturer: .omronHealthcareCoLtd, advertising: BloodPressureService.self))
                Discover(OmronWeightScale.self, by: .accessory(manufacturer: .omronHealthcareCoLtd, advertising: WeightScaleService.self))
            }

            // If required, configure the PairedDevices and HealthMeasurements modules
            PairedDevices()
            HealthMeasurements()
        }
    }
}
```

## Topics

### Omron Devices

- ``OmronBloodPressureCuff``
- ``OmronWeightScale``

### Omron Device

- ``OmronHealthDevice``
- ``OmronModel``
- ``OmronManufacturerData``
- ``SpeziBluetooth/ManufacturerIdentifier/omronHealthcareCoLtd``

### Omron Services

- ``OmronOptionService``

### Omron Record Access

- ``SpeziBluetooth/CharacteristicAccessor/reportStoredRecords(_:)``
- ``SpeziBluetooth/CharacteristicAccessor/reportNumberOfStoredRecords(_:)``
- ``SpeziBluetooth/CharacteristicAccessor/reportSequenceNumberOfLatestRecords()``
- ``OmronRecordAccessOperand``
