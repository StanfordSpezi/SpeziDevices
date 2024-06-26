//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(APISupport) import Spezi
@_spi(TestingSupport) import SpeziBluetooth
@_spi(TestingSupport) import SpeziDevices
import SpeziDevicesUI
import SpeziViews
import SwiftUI


class MockDeviceLoading: Module, EnvironmentAccessible {
    @Application(\.spezi) private var spezi

    init() {}

    func loadMockDevice(_ device: some PairableDevice) {
        spezi.loadModule(device, ownership: .external)
    }
}


struct DevicesTestView: View {
    @Environment(PairedDevices.self) private var pairedDevices
    @Environment(MockDeviceLoading.self) private var moduleLoading

    @State private var didRegister = false
    @State private var device = MockDevice.createMockDevice()

    var body: some View {
        NavigationStack {
            DevicesTab(appName: "TestApp")
                .toolbar {
                    ToolbarItemGroup(placement: .secondaryAction) {
                        Button("Discover Device", systemImage: "plus.rectangle.fill.on.rectangle.fill") {
                            device.isInPairingMode = true
                            device.$advertisementData.inject(AdvertisementData([:])) // trigger onChange advertisement
                        }
                        AsyncButton {
                            await device.connect()
                        } label: {
                            Label("Connect", systemImage: "cable.connector")
                        }
                        AsyncButton {
                            await device.disconnect()
                        } label: {
                            Label("Disconnect", systemImage: "cable.connector.slash")
                        }
                    }
                }
        }
            .onAppear {
                pairedDevices.clearStorage() // we clear storage for testing purposes

                guard !didRegister else {
                    return
                }

                moduleLoading.loadMockDevice(device)
                // simulator this being called in the configure method of the device
                pairedDevices.configure(device: device, accessing: device.$state, device.$advertisementData, device.$nearby)
                didRegister = true
            }
    }
}


#Preview {
    DevicesTestView()
        .previewWith {
            PairedDevices()
            MockDeviceLoading()
            Bluetooth {}
        }
}
