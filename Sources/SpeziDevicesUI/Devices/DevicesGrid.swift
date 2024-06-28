//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport) import SpeziDevices
import SwiftUI
import TipKit


/// Grid view of paired devices.
public struct DevicesGrid: View {
    private let devices: [PairedDeviceInfo]? // swiftlint:disable:this discouraged_optional_collection
    @Binding private var presentingDevicePairing: Bool

    @State private var detailedDeviceInfo: PairedDeviceInfo?


    private var gridItems = [
        GridItem(.adaptive(minimum: 120, maximum: 800), spacing: 12),
        GridItem(.adaptive(minimum: 120, maximum: 800), spacing: 12)
    ]


    public var body: some View {
        Group {
            if let devices {
                if devices.isEmpty {
                    ZStack {
                        VStack {
                            TipView(ForgetDeviceTip.instance)
                                .padding([.leading, .trailing], 20)
                            Spacer()
                        }
                        DevicesUnavailableView(presentingDevicePairing: $presentingDevicePairing)
                    }
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 16) {
                            TipView(ForgetDeviceTip.instance)
                                .tipBackground(Color(uiColor: .secondarySystemGroupedBackground))

                            LazyVGrid(columns: gridItems) {
                                ForEach(devices) { device in
                                    Button {
                                        detailedDeviceInfo = device
                                    } label: {
                                        DeviceTile(device)
                                    }
                                    .foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding([.leading, .trailing], 20)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
                }
            } else {
                ProgressView()
            }
        }
            .navigationTitle("Devices")
            .navigationDestination(item: $detailedDeviceInfo) { deviceInfo in
                DeviceDetailsView(deviceInfo)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Device", systemImage: "plus") {
                        presentingDevicePairing = true
                    }
                }
            }
    }


    /// Create a new devices grid.
    /// - Parameters:
    ///   - devices: The list of paired devices to display.
    ///   - presentingDevicePairing: Binding to indicate if the device discovery menu should be presented.
    public init(devices: [PairedDeviceInfo]?, presentingDevicePairing: Binding<Bool>) {
        // swiftlint:disable:previous discouraged_optional_collection
        self.devices = devices
        self._presentingDevicePairing = presentingDevicePairing
    }
}


#if DEBUG
#Preview {
    NavigationStack {
        DevicesGrid(devices: [], presentingDevicePairing: .constant(false))
    }
        .previewWith {
            PairedDevices()
        }
}

#Preview {
    let devices: [PairedDeviceInfo] = [
        .mockHealthDevice1,
        .mockHealthDevice2
    ]

    return NavigationStack {
        DevicesGrid(devices: devices, presentingDevicePairing: .constant(false))
    }
        .previewWith {
            PairedDevices()
        }
}
#endif
