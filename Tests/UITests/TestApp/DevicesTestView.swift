//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
@_spi(APISupport) import Spezi
@_spi(TestingSupport) import SpeziBluetooth
import SpeziBluetoothServices
@_spi(TestingSupport) import SpeziDevices
import SpeziDevicesUI
@_spi(TestingSupport) import SpeziOmron
import SpeziViews
import SwiftUI


class MockDeviceLoading: Module, EnvironmentAccessible {
    @Application(\.spezi) private var spezi

    init() {}

    @MainActor
    func loadMockDevice(_ device: some PairableDevice) {
        spezi.loadModule(device, ownership: .external)
    }
}


struct DevicesTestView: View {
    @Environment(PairedDevices.self) private var pairedDevices
    @Environment(MockDeviceLoading.self) private var moduleLoading

    @State private var didRegister = false
    @State private var device = MockDevice.createMockDevice()
    @State private var weightScale = OmronWeightScale.createMockDevice(manufacturerData: .omronManufacturerData(mode: .transferMode))
    @State private var bloodPressureCuff = OmronBloodPressureCuff.createMockDevice(manufacturerData: .omronManufacturerData(mode: .transferMode))

    @State private var viewState: ViewState = .idle

    var body: some View {
        NavigationStack {
            DevicesView(appName: "Example", pairingHint: "Enable pairing mode on the device.")
                .toolbar {
                    ToolbarItemGroup(placement: .secondaryAction) {
                        Button("Discover Device", systemImage: "plus.rectangle.fill.on.rectangle.fill") {
                            device.isInPairingMode = true
                            device.$advertisementData.inject(AdvertisementData()) // trigger onChange advertisement
                        }
                        AsyncButton(state: $viewState) {
                            try await device.connect()
                            try await weightScale.connect()
                            try await bloodPressureCuff.connect()
                        } label: {
                            Label("Connect", systemImage: "cable.connector")
                        }
                        AsyncButton {
                            await device.disconnect()
                            await weightScale.disconnect()
                            await bloodPressureCuff.disconnect()
                        } label: {
                            Label("Disconnect", systemImage: "cable.connector.slash")
                        }

                        Menu("Omron Devices", systemImage: "heart.text.square") {
                            Button("Discover Weight Scale", systemImage: "scalemass.fill") {
                                weightScale.$advertisementData.inject(AdvertisementData(
                                    manufacturerData: OmronManufacturerData.omronManufacturerData(mode: .pairingMode).encode()
                                ))
                            }
                            Button("Discovery Blood Pressure Cuff", systemImage: "heart.fill") {
                                bloodPressureCuff.$advertisementData.inject(AdvertisementData(
                                    manufacturerData: OmronManufacturerData.omronManufacturerData(mode: .pairingMode).encode()
                                ))
                            }
                        }
                    }
                }
        }
            .viewStateAlert(state: $viewState)
            .onAppear {
                guard !didRegister else {
                    return
                }

                moduleLoading.loadMockDevice(device)
                moduleLoading.loadMockDevice(weightScale)
                moduleLoading.loadMockDevice(bloodPressureCuff)

                // simulator this being called in the configure method of the device
                pairedDevices.configure(device: device, accessing: device.$state, device.$advertisementData, device.$nearby)
                pairedDevices.configure(device: weightScale, accessing: weightScale.$state, weightScale.$advertisementData, weightScale.$nearby)
                pairedDevices.configure(
                    device: bloodPressureCuff,
                    accessing: bloodPressureCuff.$state,
                    bloodPressureCuff.$advertisementData,
                    bloodPressureCuff.$nearby
                )
                didRegister = true
            }
    }
}


extension OmronManufacturerData {
    static func omronManufacturerData(mode: OmronManufacturerData.PairingMode) -> OmronManufacturerData {
        OmronManufacturerData(pairingMode: mode, users: [
            .init(id: 1, sequenceNumber: 2, recordsNumber: 1)
        ])
    }
}


#Preview {
    DevicesTestView()
        .previewWith {
            PairedDevices()
            MockDeviceLoading()
            Bluetooth {
                Discover(MockDevice.self, by: .accessory(manufacturer: .init(rawValue: 0x01), advertising: BloodPressureService.self))
            }
        }
}
