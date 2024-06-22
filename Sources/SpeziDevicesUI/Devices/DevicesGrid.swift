//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if DEBUG
@_spi(TestingSupport)
#endif
import SpeziDevices
import SwiftUI
import TipKit


/// Grid view of paired devices.
public struct DevicesGrid: View {
    @Binding private var devices: [PairedDeviceInfo]
    @Binding private var navigationPath: NavigationPath
    @Binding private var presentingDevicePairing: Bool


    private var gridItems = [
        GridItem(.adaptive(minimum: 120, maximum: 800), spacing: 12),
        GridItem(.adaptive(minimum: 120, maximum: 800), spacing: 12)
    ]


    public var body: some View {
        Group {
            if devices.isEmpty {
                ZStack {
                    VStack {
                        // TODO: message to check for ConfigureTipKit dependency!
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
                            ForEach($devices) { device in
                                Button {
                                    navigationPath.append(device)
                                } label: {
                                    DeviceTile(device.wrappedValue)
                                }
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                        .padding([.leading, .trailing], 20)
                }
                    .background(Color(uiColor: .systemGroupedBackground))
            }
        }
            .navigationTitle("Devices")
            .navigationDestination(for: Binding<PairedDeviceInfo>.self) { deviceInfo in
                DeviceDetailsView(deviceInfo) // TODO: prevents updates :(
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
    ///   - navigation: Binding for the navigation path.
    ///   - presentingDevicePairing: Binding to indicate if the device discovery menu should be presented.
    public init(devices: Binding<[PairedDeviceInfo]>, navigation: Binding<NavigationPath>, presentingDevicePairing: Binding<Bool>) {
        // TODO: This Interface is probably not great for public interface
        self._devices = devices
        self._navigationPath = navigation
        self._presentingDevicePairing = presentingDevicePairing
    }
}


// TODO: does that hurt? probably!!! we need to remove it anyways (for update issues)
extension Binding: Hashable, Equatable where Value: Hashable {
    public static func == (lhs: Binding<Value>, rhs: Binding<Value>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}


#if DEBUG
#Preview {
    NavigationStack {
        DevicesGrid(devices: .constant([]), navigation: .constant(NavigationPath()), presentingDevicePairing: .constant(false))
    }
        .onAppear {
            Tips.showAllTipsForTesting()
            try? Tips.configure() // TODO: use ConfigureTipKit Module
        }
        .previewWith {
            DeviceManager()
        }
}

#Preview {
    let devices: [PairedDeviceInfo] = [
        .mockHealthDevice1,
        .mockHealthDevice2
    ]

    return NavigationStack {
        DevicesGrid(devices: .constant(devices), navigation: .constant(NavigationPath()), presentingDevicePairing: .constant(false))
    }
        .onAppear {
            Tips.showAllTipsForTesting()
            try? Tips.configure() // TODO: use ConfigureTipKit Module
        }
        .previewWith {
            DeviceManager()
        }
}
#endif
