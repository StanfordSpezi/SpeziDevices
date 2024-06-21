//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct DevicesUnavailableView: View {
    @Binding private var presentingDevicePairing: Bool

    var body: some View {
        ContentUnavailableView {
            Text("No Devices")
                .fontWeight(.semibold)
        } description: {
            Text("Paired devices will appear here once set up.")
        } actions: {
            Button("Pair New Device") {
                presentingDevicePairing = true
            }
        }
    }


    init(presentingDevicePairing: Binding<Bool>) {
        self._presentingDevicePairing = presentingDevicePairing
    }
}


#if DEBUG
#Preview {
    DevicesUnavailableView(presentingDevicePairing: .constant(false))
}
#endif
