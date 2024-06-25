//
//  File.swift
//  
//
//  Created by Andreas Bauer on 25.06.24.
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
            icon: .asset("Omron-BP5250"),
            batteryPercentage: 100
        ))
    }
}
#endif
