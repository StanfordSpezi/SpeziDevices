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
    @Environment(PairedDevices.self) private var pairedDevices

    @State private var path = NavigationPath() // TODO: can we remove that? if so, might want to remove the NavigationStack from view!

    public var body: some View {
        @Bindable var pairedDevices = pairedDevices

        NavigationStack(path: $path) { // TODO: not really reusable because of the navigation stack!!!
            DevicesGrid(devices: $pairedDevices.pairedDevices, navigation: $path, presentingDevicePairing: $pairedDevices.shouldPresentDevicePairing)
                // TODO: advertisementStaleInterval: 15
                // automatically search if no devices are paired
                .scanNearbyDevices(enabled: pairedDevices.isScanningForNearbyDevices, with: bluetooth)
                // TODO: automatic pop-up is a bit unexpected!
                .sheet(isPresented: $pairedDevices.shouldPresentDevicePairing) {
                    AccessorySetupSheet(pairedDevices.discoveredDevices.values, appName: appName)
                }
                .toolbar {
                    // indicate that we are scanning in the background
                    if pairedDevices.isScanningForNearbyDevices && !pairedDevices.shouldPresentDevicePairing {
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
    DevicesTab(appName: "Example")
        .previewWith {
            Bluetooth {}
            PairedDevices()
        }
}
#endif
