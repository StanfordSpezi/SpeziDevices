# ``SpeziDevices``

Support interactions with Bluetooth Devices.

<!--

This source file is part of the Stanford Spezi open-source project

SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT

-->

## Overview

SpeziDevices abstracts common interactions with Bluetooth devices that are implemented using
[SpeziBluetooth](https://swiftpackageindex.com/StanfordSpezi/SpeziBluetooth/documentation/spezibluetooth).
It supports pairing with devices and process health measurements.

### Pairing Devices

Pairing devices is a good way of making sure that your application only connects to fixed set of devices and doesn't accept data from 
non-authorized devices.
Further, it might be necessary to ensure certain operations stay secure.

Use the ``PairedDevices`` module to discover and pair ``PairableDevice``s and automatically manage connection establishment
of connected devices.

To support `PairedDevices`, you need to adopt the ``PairableDevice`` protocol for your device.
Optionally you can adopt the ``BatteryPoweredDevice`` protocol, if your device supports the
[`BatteryService`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetoothservices/batteryservice).
Once your device is loaded, register it with the `PairedDevices` module by calling the ``configure(device:accessing:_:_:)`` method.


> Important: Don't forget to configure the `PairedDevices` module in
    your [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).

```swift
import SpeziDevices

class MyDevice: PairableDevice {
    @DeviceState(\.id) var id
    @DeviceState(\.name) var name
    @DeviceState(\.state) var state
    @DeviceState(\.advertisementData) var advertisementData
    @DeviceState(\.nearby) var nearby

    @Service var deviceInformation = DeviceInformationService()

    @DeviceAction(\.connect) var connect
    @DeviceAction(\.disconnect) var disconnect

    var isInPairingMode: Bool {
        // determine if a nearby device is in pairing mode
    }

    @Dependency private var pairedDevices: PairedDevices?

    required init() {}

    func configure() {
        pairedDevices?.configure(device: self, accessing: $state, $advertisementData, $nearby)
    }

    func handleSuccessfulPairing() { // called on events where a device can be considered paired (e.g., incoming notifications)
        pairedDevices?.signalDevicePaired(self)
    }
}
```

> Tip: To display and manage paired devices and support adding new paired devices, you can use the full-featured ``DevicesView`` view.

### Health Measurements

Use the ``HealthMeasurements`` module to collect health measurements from nearby Bluetooth devices like connected weight scales or
blood pressure cuffs.

To support `HealthMeasurements`, you need to adopt the ``HealthDevice`` protocol for your device.
One your device is loaded, register its measurement service with the `HealthMeasurements` module
by calling a suitable variant of `configureReceivingMeasurements(for:on:)`.

```swift
import SpeziDevices

class MyDevice: HealthDevice {
    @Service var deviceInformation = DeviceInformationService()
    @Service var weightScale = WeightScaleService()

    @Dependency private var measurements: HealthMeasurements?

    required init() {}

    func configure() {
        measurements?.configureReceivingMeasurements(for: self, on: weightScale)
    }
}
```

To display new measurements to the user and save them to your external data store, you can use ``MeasurementsRecordedSheet``.
Below is a short code example.

```swift
import SpeziDevices
import SpeziDevicesUI

struct MyHomeView: View {
    @Environment(HealthMeasurements.self) private var measurements

    var body: some View {
        @Bindable var measurements = measurements
        ContentView()
            .sheet(isPresented: $measurements.shouldPresentMeasurements) {
                MeasurementsRecordedSheet { measurement in
                    // handle saving the measurement
                }
            }
    }
}
```

> Important: Don't forget to configure the `HealthMeasurements` module in
    your [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).

## Topics

### Device Pairing

- ``PairedDevices``
- ``PairedDeviceInfo``
- ``DevicePairingError``
- ``ImageReference``

### Devices

- ``GenericBluetoothPeripheral``
- ``GenericDevice``
- ``BatteryPoweredDevice``
- ``PairableDevice``

### Processing Measurements

- ``HealthMeasurements``
- ``HealthDevice``
- ``BluetoothHealthMeasurement``
- <doc:HealthKit>
- ``HealthKitMeasurement``
