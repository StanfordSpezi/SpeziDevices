//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(Internal)
@_spi(TestingSupport)
import SpeziDevices
import SpeziViews
import SwiftUI

@available(iOS 18, macOS 15, tvOS 18, visionOS 2, watchOS 11, *) // TODO: unecessary! not used at all
struct TimerIntervalLabel: View {
    private let date: Date

    var body: some View {
        if Calendar.current.isDateInToday(date) {
            Text(
                .currentDate,
                format: SystemFormatStyle.DateReference(
                    to: date,
                    allowedFields: [.year, .month, .day, .hour, .minute, .second],
                    maxFieldCount: 2,
                    thresholdField: .day
                )
            )
        } else if Calendar.current.isDateInYesterday(date) {
            Text("yesterday, \(Text(date, style: .time))", bundle: .module)
        } else {
            Text("\(Text(date, format: Date.FormatStyle(date: .complete))), \(Text(date, style: .time))", bundle: .module)
        }
    }

    init(_ date: Date) {
        self.date = date
    }
}

#Preview {
    if #available(iOS 18, *) {
        TimerIntervalLabel(Date.now.addingTimeInterval(-45)) // seconds
        TimerIntervalLabel(Date.now.addingTimeInterval(-2 * 60)) // minutes
        TimerIntervalLabel(Date.now.addingTimeInterval(-8 * 60 * 60)) // hours
        TimerIntervalLabel(Date.now.addingTimeInterval(-1 * 24 * 60 * 60)) // yesterday
        TimerIntervalLabel(Date.now.addingTimeInterval(-8 * 24 * 60 * 60)) // days
        TimerIntervalLabel(.now.addingTimeInterval(-25 * 24 * 60 * 60)) // weeks
        TimerIntervalLabel(.now.addingTimeInterval(-31 * 24 * 60 * 60)) // months

    } else {
        // Fallback on earlier versions
    }
}


/// Show the device details of a paired device.
public struct DeviceDetailsView: View {
    private let deviceInfo: PairedDeviceInfo

    @Environment(\.dismiss)
    private var dismiss
    @Environment(PairedDevices.self)
    private var pairedDevices

    @State private var viewState: ViewState = .idle
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
                    LabeledContent {
                        BatteryIcon(percentage: Int(percentage))
                            .labelStyle(.reverse)
                    } label: {
                        Text("Battery", bundle: .module)
                    }
                        .accessibilityElement(children: .combine)
                }
            }

            Section {
                AsyncButton(state: $viewState) {
                    presentForgetConfirmation = true
                } label: {
                    Text("Forget This Device", bundle: .module)
                }
            } footer: {
                if pairedDevices.isConnected(device: deviceInfo.id) {
                    Text("Synchronizing ...", bundle: .module)
                } else if lastSeenToday {
                    Text("This device was last seen at \(Text(deviceInfo.lastSeen, style: .time))", bundle: .module)
                } else {
                    Text(
                        "This device was last seen on \(Text(deviceInfo.lastSeen, style: .date)) at \(Text(deviceInfo.lastSeen, style: .time))",
                        bundle: .module
                    )
                }
            }
        }
            .navigationTitle(Text("Device Details", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .viewStateAlert(state: $viewState)
            .confirmationDialog(
                Text("Do you really want to forget this device?", bundle: .module),
                isPresented: $presentForgetConfirmation,
                titleVisibility: .visible
            ) {
                Button {
                    forgetDevice()
                } label: {
                    Text("Forget Device", bundle: .module)
                }
                Button(role: .cancel) {} label: {
                    Text("Cancel", bundle: .module)
                }
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
                .foregroundStyle(Color.accentColor) // set accent color if one uses sf symbols
                .symbolRenderingMode(.hierarchical) // set symbol rendering mode if one uses sf symbols
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

    private func forgetDevice() {
        guard case .idle = viewState else {
            return
        }

        viewState = .processing

        Task {
            do {
                let managedByAccessorySetupKit = if #available(iOS 18, *), deviceInfo.accessory != nil {
                    true
                } else {
                    false
                }
                try await pairedDevices.forgetDevice(id: deviceInfo.id)
                if !managedByAccessorySetupKit {
                    ForgetDeviceTip.hasRemovedPairedDevice = true
                }
                dismiss()
                viewState = .idle
            } catch {
                viewState = .error(AnyLocalizedError(
                    error: error,
                    defaultErrorDescription: .init("Failed to forget device", bundle: .atURL(from: .module))
                ))
            }
        }
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
            lastSeen: .now.addingTimeInterval(-120),
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
            lastSeen: .now.addingTimeInterval(-60 * 60 * 24),
            batteryPercentage: 85
        ))
    }
        .previewWith {
            PairedDevices()
        }
}
#endif
