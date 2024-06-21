//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziDevices
import SpeziViews
import SwiftUI


struct AccessorySetupSheet<Collection: RandomAccessCollection>: View where Collection.Element == any PairableDevice {
    private let devices: Collection

    @Environment(DeviceManager.self) private var deviceManager
    @Environment(\.dismiss) private var dismiss

    @State private var pairingState: PairingState = .discovery

    var body: some View {
        NavigationStack {
            VStack {
                // TODO: make ONE PaneContent? => animation of image transfer?
                if case let .error(error) = pairingState {
                    PairingFailureView(error)
                } else if case let .paired(device) = pairingState {
                    PairedDeviceView(device)
                } else if !devices.isEmpty {
                    PairDeviceView(devices: devices, state: $pairingState) { device in
                        try await device.pair()
                        await deviceManager.registerPairedDevice(device)
                    }
                } else {
                    DiscoveryView()
                }
            }
                .toolbar { // TODO: where to put that?
                    DismissButton()
                }
        }
        .presentationDetents([.medium])
        .presentationCornerRadius(25)
        .interactiveDismissDisabled()
    }

    init(_ devices: Collection) {
        self.devices = devices
    }
}


#if DEBUG
#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            AccessorySetupSheet([MockDevice.createMockDevice()])
        }
        .previewWith {
            DeviceManager()
        }
}


#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            let devices: [any PairableDevice] = [
                MockDevice.createMockDevice(name: "Device 1"),
                MockDevice.createMockDevice(name: "Device 2")
            ]
            AccessorySetupSheet(devices)
        }
        .previewWith {
            DeviceManager()
        }
}

#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            AccessorySetupSheet([])
        }
        .previewWith {
            DeviceManager()
        }
}
#endif
