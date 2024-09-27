//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(Internal) import SpeziDevices
import SpeziViews
import SwiftUI


struct DeviceInfoSection: View {
    private let deviceInfo: PairedDeviceInfo

    @Environment(PairedDevices.self) private var pairedDevices

    var body: some View {
        Section {
            if #available(iOS 18, *), let accessory = pairedDevices.accessory(for: deviceInfo.id) {
                AccessoryRenameButton(accessory: accessory)
            } else {
                NavigationLink {
                    NameEditView(deviceInfo) { name in
                        pairedDevices.updateName(for: deviceInfo, name: name)
                    }
                } label: {
                    LabeledContent {
                        Text(deviceInfo.name)
                    } label: {
                        Text("Name", bundle: .module)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            if let model = deviceInfo.model, model != deviceInfo.name {
                LabeledContent {
                    Text(model)
                } label: {
                    Text("Model", bundle: .module)
                }
                    .accessibilityElement(children: .combine)
            }
        }
    }


    init(deviceInfo: PairedDeviceInfo) {
        self.deviceInfo = deviceInfo
    }
}


#if DEBUG
#Preview {
    NavigationStack {
        List {
            DeviceInfoSection(deviceInfo: PairedDeviceInfo(
                id: UUID(),
                deviceType: "MockDevice",
                name: "Blood Pressure Monitor",
                model: "BP5250",
                batteryPercentage: 100
            ))
        }
            .previewWith {
                PairedDevices()
            }
    }
}
#endif
