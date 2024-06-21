//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BluetoothServices
import Foundation
@_spi(TestingSupport) import SpeziBluetooth
import SpeziDevices


#if DEBUG
final class MockDevice: PairableDevice, Identifiable {    
    @DeviceState(\.id) var id
    @DeviceState(\.name) var name
    @DeviceState(\.state) var state
    @DeviceState(\.advertisementData) var advertisementData
    @DeviceState(\.discarded) var discarded

    @DeviceAction(\.connect) var connect
    @DeviceAction(\.disconnect) var disconnect


    @Service var deviceInformation = DeviceInformationService()

    let pairing = PairingContinuation()
    var isInPairingMode = false // TODO: control

    // TODO: mandatory setup?
}


extension MockDevice {
    static func createMockDevice(name: String = "Mock Device", state: PeripheralState = .disconnected) -> MockDevice {
        let device = MockDevice()

        device.deviceInformation.$manufacturerName.inject("Mock Company")
        device.deviceInformation.$modelNumber.inject("MD1")
        device.deviceInformation.$hardwareRevision.inject("2")
        device.deviceInformation.$firmwareRevision.inject("1.0")

        device.$id.inject(UUID())
        device.$name.inject(name)
        device.$state.inject(state)

        device.$connect.inject { @MainActor [weak device] in
            device?.$state.inject(.connecting)
            // TODO: await device?.handleStateChange(.connecting)

            try? await Task.sleep(for: .seconds(1))

            device?.$state.inject(.connected)
            // TODO: await device?.handleStateChange(.connected)
        }

        device.$disconnect.inject { @MainActor [weak device] in
            device?.$state.inject(.disconnected)
            // TODO: await device?.handleStateChange(.disconnected)
        }

        return device
    }
}
#endif
