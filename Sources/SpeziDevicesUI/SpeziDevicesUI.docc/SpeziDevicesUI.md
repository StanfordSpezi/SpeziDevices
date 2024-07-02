# ``SpeziDevicesUI``

Visualize Bluetooth device interactions.

<!--

This source file is part of the Stanford Spezi open-source project

SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT

-->

## Overview

SpeziDevicesUI helps you to visualize Bluetooth device state and communicate interactions to the user.

### Displaying paired devices

When managing paired devices using ``PairedDevices``, SpeziDevicesUI provides reusable View components to display paired devices.

The ``DevicesView`` provides everything you need to pair and manage paired devices. 
It shows already paired devices in a grid layout using the ``DevicesGrid``. Additionally, it places an add button in the toolbar
to discover new devices using the ``AccessorySetupSheet`` view.

```swift
struct MyHomeView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DevicesView(appName: "Example") {
                    Text("Provide helpful pairing instructions to the user.")
                }
            }
                .tabItem {
                    Label("Devices", systemImage: "sensor.fill")
                }
        }
    }
}
```

### Displaying Measurements

When managing measurements using ``HealthMeasurements``, you can use the ``MeasurementsRecordedSheet`` to display pending measurements.
Below is a short code example on how you would configure this view.

```swift
struct MyHomeView: View {
    @Environment(HealthMeasurements.self) private var measurements

    var body: some View {
        @Bindable var measurements = measurements
        ContentView()
            .sheet(isPresented: $measurements.shouldPresentMeasurements) {
                MeasurementsRecordedSheet { samples in
                    // save the array of HKSamples
                }
            }
    }
}
```

> Important: Don't forget to configure the `HealthMeasurements` module in
    your [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).

## Topics

### Presenting nearby devices

Views that are helpful when building a nearby devices view.

- ``BluetoothUnavailableView``
- ``NearbyDeviceRow``
- ``LoadingSectionHeader``

### Pairing Devices

- ``AccessorySetupSheet``

### Paired Devices

- ``DevicesView``
- ``DevicesGrid``
- ``DeviceTile``
- ``DeviceDetailsView``
- ``BatteryIcon``

### Measurements

- ``MeasurementsRecordedSheet``
