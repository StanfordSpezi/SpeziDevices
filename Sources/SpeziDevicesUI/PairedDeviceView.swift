//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziDevices
import SwiftUI


struct PairedDeviceView: View {
    private let device: any PairableDevice

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PaneContent(title: "Accessory Paired", subtitle: "\"\(device.label)\" was successfully paired with the ENGAGE app.") {
            AccessoryImageView(device)
        } action: {
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity, maxHeight: 35)
            }
            .buttonStyle(.borderedProminent)
            .padding([.leading, .trailing], 36)
        }
    }


    init(_ device: any PairableDevice) {
        self.device = device
    }
}


#if DEBUG
#Preview {
    SheetPreview {
        PairedDeviceView(MockDevice.createMockDevice())
    }
}
#endif
