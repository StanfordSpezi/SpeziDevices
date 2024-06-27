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
            ListRow("Name") {
                Text(device.label)
            }
            if let model = device.deviceInformation.modelNumber {
                ListRow("Model") {
                    Text(model)
                }
            }
            if let firmwareVersion = device.deviceInformation.firmwareRevision {
                ListRow("Firmware Version") {
                    Text(firmwareVersion)
                }
            }
            if let battery = device.battery.batteryLevel {
                ListRow("Battery") {
                    BatteryIcon(percentage: Int(battery))
                        .labelStyle(.reverse)
                }
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
