<!--
                  
This source file is part of the Stanford SpeziDevices open source project

SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT
             
-->

# SpeziDevices

[![Build and Test](https://github.com/StanfordSpezi/SpeziDevices/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/StanfordSpezi/SpeziDevices/actions/workflows/build-and-test.yml)
[![codecov](https://codecov.io/gh/StanfordSpezi/SpeziDevices/graph/badge.svg?token=pZeJyWYhAk)](https://codecov.io/gh/StanfordSpezi/SpeziDevices)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.12627487.svg)](https://doi.org/10.5281/zenodo.12627487)
<!-- TODO: SPI BADGES-->

Support interactions with Bluetooth Devices.

## Overview

SpeziDevices provides three different targets: `SpeziDevices`, `SpeziDevicesUI` and `SpeziOmron`.

### SpeziDevices

SpeziDevices abstracts common interactions with Bluetooth devices that are implemented using
[SpeziBluetooth](https://swiftpackageindex.com/StanfordSpezi/SpeziBluetooth/documentation/spezibluetooth).
It supports pairing with devices and process health measurements.

#### Pairing Devices

Pairing devices is a good way of making sure that your application only connects to fixed set of devices and doesn't accept data from 
non-authorized devices.
Further, it might be necessary to ensure certain operations stay secure.

Use the [`PairedDevices`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/paireddevices)
module to discover and pair ``PairableDevice``s and automatically manage connection establishment
of connected devices.

To support `PairedDevices`, you need to adopt the ``PairableDevice`` protocol for your device.
Optionally you can adopt the ``BatteryPoweredDevice`` protocol, if your device supports the
[`BatteryService`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetoothservices/batteryservice).
Once your device is loaded, register it with the `PairedDevices` module by calling the ``PairedDevices/configure(device:accessing:_:_:)`` method.


> [!IMPORTANT]
> Don't forget to configure the `PairedDevices` module in
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

> [!TIP]
> To display and manage paired devices and support adding new paired devices, you can use the full-featured
  [`DevicesView`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevicesui/devicesview).

#### Health Measurements

Use the [`HealthMeasurements`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/healthmeasurements)
module to collect health measurements from nearby Bluetooth devices like connected weight scales or
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

To display new measurements to the user and save them to your external data store, you can use
[`MeasurementsRecordedSheet`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevicesui/measurementsrecordedsheet).
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

> [!IMPORTANT]
> Don't forget to configure the `HealthMeasurements` module in
  your [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).

### SpeziDevicesUI

SpeziDevicesUI helps you to visualize Bluetooth device state and communicate interactions to the user.

#### Displaying paired devices

When managing paired devices using [`PairedDevices`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/paireddevices),
SpeziDevicesUI provides reusable View components to display paired devices.

The [`DevicesView`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevicesui/devicesview)
provides everything you need to pair and manage paired devices. 
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

#### Displaying Measurements

When managing measurements using [`HealthMeasurements`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/healthmeasurements),
you can use the [`MeasurementsRecordedSheet`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevicesui/measurementsrecordedsheet)
to display pending measurements.
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

> [!IMPORTANT]
> Don't forget to configure the `HealthMeasurements` module in
  your [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).
    
### SpeziOmron

SpeziOmron extends SpeziDevices with support for Omron devices. This includes Omron-specific models, characteristics, services and fully reusable
device support.

#### Omron Devices

The ``OmronBloodPressureCuff`` and ``OmronWeightScale`` devices provide reusable device implementations for the Omron `BP5250` blood pressure cuff
and the Omron `SC-150` weight scale.
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

## Setup

You need to add the SpeziDevices Swift package to
[your app in Xcode](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app#) or
[Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode#Add-a-dependency-on-another-Swift-package).

## License
This project is licensed under the MIT License. See [Licenses](https://github.com/StanfordSpezi/SpeziDevices/tree/main/LICENSES) for more information.


## Contributors
This project is developed as part of the Stanford Byers Center for Biodesign at Stanford University.
See [CONTRIBUTORS.md](https://github.com/StanfordSpezi/SpeziDevices/tree/main/CONTRIBUTORS.md) for a full list of all TemplatePackage contributors.

![Stanford Byers Center for Biodesign Logo](https://raw.githubusercontent.com/StanfordSpezi/.github/main/assets/Footer.png#gh-light-mode-only)
![Stanford Byers Center for Biodesign Logo](https://raw.githubusercontent.com/StanfordSpezi/.github/main/assets/Footer~dark.png#gh-dark-mode-only)
