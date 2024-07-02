//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport) import SpeziDevices
import SpeziViews
import SwiftUI


/// Show the device details of a paired device.
public struct DeviceDetailsView: View {
    private let deviceInfo: PairedDeviceInfo

    @Environment(\.dismiss) private var dismiss
    @Environment(PairedDevices.self) private var pairedDevices

    @State private var presentForgetConfirmation = false

    private var image: Image {
        deviceInfo.icon?.image ?? Image(systemName: "sensor") // swiftlint:disable:this accessibility_label_for_image
    }

    private var lastSeenToday: Bool {
        Calendar.current.isDateInToday(deviceInfo.lastSeen)
    }

    public var body: some View {
        List {
            Section {
                imageHeader
            }

            DeviceInfoSection(deviceInfo: deviceInfo)

            if let percentage = deviceInfo.lastBatteryPercentage {
                Section {
                    ListRow("Battery") {
                        BatteryIcon(percentage: Int(percentage))
                            .labelStyle(.reverse)
                    }
                }
            }

            Section {
                Button("Forget This Device") {
                    presentForgetConfirmation = true
                }
            } footer: {
                if pairedDevices.isConnected(device: deviceInfo.id) {
                    Text("Synchronizing ...")
                } else if lastSeenToday {
                    Text("This device was last seen at \(Text(deviceInfo.lastSeen, style: .time))")
                } else {
                    Text("This device was last seen on \(Text(deviceInfo.lastSeen, style: .date)) at \(Text(deviceInfo.lastSeen, style: .time))")
                }
            }
        }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Do you really want to forget this device?", isPresented: $presentForgetConfirmation, titleVisibility: .visible) {
                Button("Forget Device", role: .destructive) {
                    ForgetDeviceTip.hasRemovedPairedDevice = true
                    pairedDevices.forgetDevice(id: deviceInfo.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .toolbar {
                if pairedDevices.isConnected(device: deviceInfo.id) {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView()
                    }
                }
            }
    }

    @ViewBuilder private var imageHeader: some View {
        VStack(alignment: .center) {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 180, maxHeight: 120)
                .accessibilityHidden(true)
        }
            .frame(maxWidth: .infinity)
    }


    /// Create a new device details view.
    /// - Parameter deviceInfo: The device info of the paired device.
    public init(_ deviceInfo: PairedDeviceInfo) {
        self.deviceInfo = deviceInfo
    }
}


#if DEBUG
#Preview {
    NavigationStack {
        DeviceDetailsView(PairedDeviceInfo(
            id: UUID(),
            deviceType: MockDevice.deviceTypeIdentifier,
            name: "Blood Pressure Monitor",
            model: "BP5250",
            icon: .asset("Omron-BP5250"),
            batteryPercentage: 100
        ))
    }
        .previewWith {
            PairedDevices()
        }
}

#Preview {
    NavigationStack {
        DeviceDetailsView(PairedDeviceInfo(
            id: UUID(),
            deviceType: MockDevice.deviceTypeIdentifier,
            name: "Weight Scale",
            model: "SC-150",
            icon: .asset("Omron-SC-150"),
            lastSeen: .now.addingTimeInterval(-60 * 60 * 24),
            batteryPercentage: 85
        ))
    }
        .previewWith {
            PairedDevices()
        }
}
#endif
