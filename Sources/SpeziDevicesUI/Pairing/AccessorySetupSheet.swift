//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import OSLog
import SpeziBluetooth
@_spi(TestingSupport) import SpeziDevices
import SpeziViews
import SwiftUI


/// Accessory Setup view displayed in a sheet.
public struct AccessorySetupSheet<Collection: RandomAccessCollection>: View where Collection.Element == any PairableDevice {
    private static var logger: Logger {
        Logger(subsystem: "edu.stanford.sepzi.SpeziDevices", category: "AccessorySetupSheet")
    }

    private let devices: Collection
    private let appName: String

    @Environment(Bluetooth.self) private var bluetooth
    @Environment(PairedDevices.self) private var pairedDevices
    @Environment(\.dismiss) private var dismiss

    @State private var pairingState: PairingViewState = .discovery

    public var body: some View {
        NavigationStack {
            VStack {
                // TODO: make ONE PaneContent? => animation of image transfer?
                if case let .error(error) = pairingState {
                    PairingFailureView(error)
                } else if case let .paired(device) = pairingState {
                    PairedDeviceView(device, appName: appName)
                } else if !devices.isEmpty {
                    PairDeviceView(devices: devices, appName: appName, state: $pairingState) { device in
                        do {
                            try await pairedDevices.pair(with: device)
                        } catch {
                            Self.logger.error("Failed to pair device \(device.id), \(device.name ?? "unnamed"): \(error)")
                            throw error
                        }
                    }
                } else {
                    DiscoveryView()
                }
            }
                .toolbar {
                    DismissButton()
                }
        }
            .scanNearbyDevices(with: bluetooth)
            .presentationDetents([.medium])
            .presentationCornerRadius(25)
            .interactiveDismissDisabled()
    }

    /// Create a new Accessory Setup sheet.
    /// - Parameters:
    ///   - devices: The collection of nearby devices which are available for pairing.
    ///   - appName: The name of the application to show in the pairing UI.
    public init(_ devices: Collection, appName: String) {
        self.devices = devices
        self.appName = appName
    }
}


#if DEBUG
#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            AccessorySetupSheet([MockDevice.createMockDevice()], appName: "Example")
        }
        .previewWith {
            Bluetooth {}
            PairedDevices()
        }
}


#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            let devices: [any PairableDevice] = [
                MockDevice.createMockDevice(name: "Device 1"),
                MockDevice.createMockDevice(name: "Device 2")
            ]
            AccessorySetupSheet(devices, appName: "Example")
        }
        .previewWith {
            Bluetooth {}
            PairedDevices()
        }
}

#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            AccessorySetupSheet([], appName: "Example")
        }
        .previewWith {
            Bluetooth {}
            PairedDevices()
        }
}
#endif
