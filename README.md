<!--
                  
This source file is part of the Stanford SpeziDevices open source project

SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT
             
-->

# SpeziDevices

[![Build and Test](https://github.com/StanfordSpezi/SpeziDevices/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/StanfordSpezi/SpeziDevices/actions/workflows/build-and-test.yml)
[![codecov](https://codecov.io/gh/StanfordSpezi/SpeziDevices/graph/badge.svg?token=pZeJyWYhAk)](https://codecov.io/gh/StanfordSpezi/SpeziDevices)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.12627487.svg)](https://doi.org/10.5281/zenodo.12627487)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FStanfordSpezi%2FSpeziDevices%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/StanfordSpezi/SpeziDevices)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FStanfordSpezi%2FSpeziDevices%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/StanfordSpezi/SpeziDevices)

Support interactions with Bluetooth Devices.

## Overview

SpeziDevices provides three different targets: [`SpeziDevices`](https://swiftpackageindex.com/StanfordSpezi/SpeziDevices/documentation/spezidevices),
[`SpeziDevicesUI`](https://swiftpackageindex.com/StanfordSpezi/SpeziDevices/documentation/spezidevicesui)
and [`SpeziOmron`](https://swiftpackageindex.com/StanfordSpezi/SpeziDevices/documentation/speziomron).

|![Screenshot showing paired devices in a grid layout. A sheet is presented in the foreground showing a nearby devices able to pair.](Sources/SpeziDevicesUI/SpeziDevicesUI.docc/Resources/PairedDevices.png#gh-light-mode-only) ![Screenshot showing paired devices in a grid layout. A sheet is presented in the foreground showing a nearby devices able to pair.](Sources/SpeziDevicesUI/SpeziDevicesUI.docc/Resources/PairedDevices~dark.png#gh-dark-mode-only)|![Displaying the device details of a paired device with information like Model number and battery percentage.](Sources/SpeziDevicesUI/SpeziDevicesUI.docc/Resources/DeviceDetails.png#gh-light-mode-only) ![Displaying the device details of a paired device with information like Model number and battery percentage.](Sources/SpeziDevicesUI/SpeziDevicesUI.docc/Resources/DeviceDetails~dark.png#gh-dark-mode-only)| ![Showing a newly recorded blood pressure measurement.](Sources/SpeziDevicesUI/SpeziDevicesUI.docc/Resources/MeasurementRecorded_BloodPressure.png#gh-light-mode-only) ![Showing a newly recorded blood pressure measurement.](Sources/SpeziDevicesUI/SpeziDevicesUI.docc/Resources/MeasurementRecorded_BloodPressure~dark.png#gh-dark-mode-only) |
|:--:|:--:|:--:|
|Display paired in a grid-layout devices using [`DevicesView`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevicesui/devicesview).|Display device details using [`DeviceDetailsView`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevicesui/devicedetailsview).|Display recorded measurements using [`MeasurementsRecordedSheet`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevicesui/measurementsrecordedsheet).|

### SpeziDevices

SpeziDevices abstracts common interactions with Bluetooth devices that are implemented using
[SpeziBluetooth](https://swiftpackageindex.com/StanfordSpezi/SpeziBluetooth/documentation/spezibluetooth).
It supports pairing with devices and process health measurements.

#### Pairing Devices

Pairing devices is a good way of making sure that your application only connects to fixed set of devices and doesn't accept data from 
non-authorized devices.
Further, it might be necessary to ensure certain operations stay secure.

Use the [`PairedDevices`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/paireddevices)
module to discover and pair [`PairableDevice`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/pairabledevice)s
and automatically manage connection establishment of connected devices.

To support `PairedDevices`, you need to adopt the
[`PairableDevice`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/pairabledevice) protocol for your device.
Optionally you can adopt the [`BatteryPoweredDevice`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/batterypowereddevice)
protocol, if your device supports the
[`BatteryService`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetoothservices/batteryservice).
Once your device is loaded, register it with the `PairedDevices` module by calling the
[`PairedDevices/configure(device:accessing:_:_:)`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/paireddevices/configure(device:accessing:_:_:))
method.


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

To support `HealthMeasurements`, you need to adopt the [`HealthDevice`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/healthdevice) protocol for your device.
One your device is loaded, register its measurement service with the `HealthMeasurements` module
by calling a suitable variant of [`configureReceivingMeasurements(for:on:)`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/healthmeasurements#register-devices).

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
It shows already paired devices in a grid layout using the [`DevicesGrid`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevicesui/devicesgrid).
Additionally, it places an add button in the toolbar to discover new devices using the
[`AccessorySetupSheet`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevicesui/accessorysetupsheet) view.

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

The [`OmronBloodPressureCuff`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/speziomron/omronbloodpressurecuff)
and [`OmronWeightScale`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/speziomron/omronweightscale)
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
                Discover(OmronBloodPressureCuff.self, by: .advertisedService(BloodPressureService.self))
                Discover(OmronWeightScale.self, by: .advertisedService(WeightScaleService.self))
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
