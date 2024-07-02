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



- models (e.g., manufcaturer data)
- characteristic & services
- device implementations

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
