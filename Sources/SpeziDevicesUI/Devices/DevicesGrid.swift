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
    private let pairNewDevice: (() -> Void)?

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
                        DevicesUnavailableView(showPairing: pairNewDevice)
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
            // TODO: this is a problem when this view is presented inside a
            .navigationDestination(item: $detailedDeviceInfo) { deviceInfo in
                DeviceDetailsView(deviceInfo)
            }
    }


    /// Create a new devices grid.
    /// - Parameters:
    ///   - devices: The list of paired devices to display.
    ///   - presentingDevicePairing: Binding to indicate if the device discovery menu should be presented.
    ///     The view shows an `ContentUnavailableView` if no paired devices exists and uses the binding to provide an action that present device pairing.
    @available(*, deprecated, message: "Please migrate to the new closure-based init(devices:showPairing:) initializer.")
    public init(devices: [PairedDeviceInfo]?, presentingDevicePairing: Binding<Bool>) {
        // swiftlint:disable:previous discouraged_optional_collection
        self.init(devices: devices) {
            presentingDevicePairing.wrappedValue = true
        }
    }
    
    /// Create a new devices grid.
    /// - Parameter devices: The list of paired devices to display.
    public init(devices: [PairedDeviceInfo]?) {
        // swiftlint:disable:previous discouraged_optional_collection
        self.devices = devices
        self.pairNewDevice = nil
    }
    
    /// Create a new devices grid.
    /// - Parameters:
    ///   - devices: The list of paired devices to display.
    ///   - pairNewDevice: Action that is called if the user request to pair a new device. This might be used to present a "Pair New Device" action in the
    ///     content unavailable view.
    public init(devices: [PairedDeviceInfo]?, showPairing pairNewDevice: @escaping () -> Void) {
        // swiftlint:disable:previous discouraged_optional_collection
        self.devices = devices
        self.pairNewDevice = pairNewDevice
    }
}


#if DEBUG
#Preview {
    NavigationStack {
        DevicesGrid(devices: []) {}
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
        DevicesGrid(devices: devices) {}
    }
        .previewWith {
            PairedDevices()
        }
}
#endif
