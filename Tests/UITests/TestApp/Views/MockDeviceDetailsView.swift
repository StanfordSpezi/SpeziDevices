//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport) import SpeziDevices
import SpeziDevicesUI
import SpeziViews
import SwiftUI


struct MockDeviceDetailsView: View {
    private let device: MockDevice

    var body: some View {
        List {
            LabeledContent("Name", value: device.label)
                .accessibilityElement(children: .combine)
            if let model = device.deviceInformation.modelNumber {
                LabeledContent("Model", value: model)
                    .accessibilityElement(children: .combine)
            }
            if let firmwareVersion = device.deviceInformation.firmwareRevision {
                LabeledContent("Firmware Version", value: firmwareVersion)
                    .accessibilityElement(children: .combine)
            }
            if let battery = device.battery.batteryLevel {
                LabeledContent("Battery") {
                    BatteryIcon(percentage: Int(battery))
                        .labelStyle(.reverse)
                }
                    .accessibilityElement(children: .combine)
            }
        }
            .navigationTitle(device.label)
            .navigationBarTitleDisplayMode(.inline)
    }

    init(_ device: MockDevice) {
        self.device = device
    }
}


#Preview {
    NavigationStack {
        MockDeviceDetailsView(MockDevice.createMockDevice())
    }
}
