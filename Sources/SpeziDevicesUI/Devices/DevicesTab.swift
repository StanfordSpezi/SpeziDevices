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
///
/// - Note: Make sure to place this view into an `NavigationStack`.
public struct DevicesTab: View {
    private let appName: String

    @Environment(Bluetooth.self) private var bluetooth
    @Environment(PairedDevices.self) private var pairedDevices

    public var body: some View {
        @Bindable var pairedDevices = pairedDevices

        DevicesGrid(devices: pairedDevices.pairedDevices, presentingDevicePairing: $pairedDevices.shouldPresentDevicePairing)
            // automatically search if no devices are paired
            .scanNearbyDevices(enabled: pairedDevices.isScanningForNearbyDevices, with: bluetooth, advertisementStaleInterval: 15)
            // TODO: advertisementStaleInterval: 15
            .sheet(isPresented: $pairedDevices.shouldPresentDevicePairing) {
                AccessorySetupSheet(pairedDevices.discoveredDevices.values, appName: appName)
            }
            .toolbar {
                // indicate that we are scanning in the background
                if pairedDevices.isScanningForNearbyDevices && !pairedDevices.shouldPresentDevicePairing {
                    ProgressView()
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
    NavigationStack {
        DevicesTab(appName: "Example")
            .previewWith {
                Bluetooth {}
                PairedDevices()
            }
    }
}
#endif
