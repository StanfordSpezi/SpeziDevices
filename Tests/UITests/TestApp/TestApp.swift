//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziBluetooth
import SpeziBluetoothServices
@_spi(TestingSupport) import SpeziDevices
import SpeziDevicesUI
import SwiftUI


class TestAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth {
                Discover(MockDevice.self, by: .accessory(manufacturer: .init(rawValue: 0x01), advertising: BloodPressureService.self))
            }
            PairedDevices()
            HealthMeasurements()
            MockDeviceLoading()
        }
    }
}


@main
struct TestApp: App {
    @ApplicationDelegateAdaptor(TestAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .spezi(delegate)
        }
    }
}
