//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziDevices
import SpeziViews
import SwiftUI


struct DeviceInfoSection: View {
    private let deviceInfo: PairedDeviceInfo

    @Environment(PairedDevices.self) private var pairedDevices

    var body: some View {
        Section {
            NavigationLink {
                NameEditView(deviceInfo) { name in
                    pairedDevices.updateName(for: deviceInfo, name: name)
                }
            } label: {
                ListRow("Name") {
                    Text(deviceInfo.name)
                }
            }

            if let model = deviceInfo.model, model != deviceInfo.name {
                ListRow("Model") {
                    Text(model)
                }
            }
        }
    }


    init(deviceInfo: PairedDeviceInfo) {
        self.deviceInfo = deviceInfo
    }
}


#if DEBUG
#Preview {
    List {
        DeviceInfoSection(deviceInfo: PairedDeviceInfo(
            id: UUID(),
            deviceType: "MockDevice",
            name: "Blood Pressure Monitor",
            model: "BP5250",
            batteryPercentage: 100
        ))
    }
}
#endif
