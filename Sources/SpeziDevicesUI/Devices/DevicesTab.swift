//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SpeziDevices
import SwiftUI


/// Devices tab showing grid of paired devices and functionality to pair new devices.
public struct DevicesTab: View {
    private let appName: String

    @Environment(Bluetooth.self) private var bluetooth
    @Environment(DeviceManager.self) private var deviceManager

    @State private var path = NavigationPath() // TODO: can we remove that? if so, might want to remove the NavigationStack from view!

    public var body: some View {
        @Bindable var deviceManager = deviceManager

        NavigationStack(path: $path) { // TODO: not really reusable because of the navigation stack!!!
            DevicesGrid(devices: $deviceManager.pairedDevices, navigation: $path, presentingDevicePairing: $deviceManager.presentingDevicePairing)
                .scanNearbyDevices(enabled: deviceManager.scanningNearbyDevices, with: bluetooth) // automatically search if no devices are paired
                .sheet(isPresented: $deviceManager.presentingDevicePairing) {
                    AccessorySetupSheet(deviceManager.discoveredDevices.values, appName: appName)
                }
                .toolbar {
                    // indicate that we are scanning in the background
                    if deviceManager.scanningNearbyDevices && !deviceManager.presentingDevicePairing {
                        ToolbarItem(placement: .cancellationAction) { // TODO: shall we do primary action (what about order then?)
                            ProgressView()
                        }
                    }
                }
        }
    }

    /// Create a new devices tab
    /// - Parameter appName: The name of the application to show in the pairing UI.
    public init(appName: String) {
        self.appName = appName
    }
}


#if DEBUG
#Preview {
    PairingSheet()
        .previewWith {
            Bluetooth {}
            DeviceManager()
        }
}
#endif
