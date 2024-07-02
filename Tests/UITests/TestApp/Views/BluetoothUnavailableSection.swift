//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziDevicesUI
import SwiftUI


struct BluetoothUnavailableSection: View {
    var body: some View {
        Section("Bluetooth Unavailable") {
            NavigationLink("Bluetooth Powered Off") {
                BluetoothUnavailableView(.poweredOff)
            }
            NavigationLink("Bluetooth Powered On") {
                BluetoothUnavailableView(.poweredOn)
            }
            NavigationLink("Bluetooth Unauthorized") {
                BluetoothUnavailableView(.unauthorized)
            }
            NavigationLink("Bluetooth Unsupported") {
                BluetoothUnavailableView(.unsupported)
            }
            NavigationLink("Bluetooth Unknown") {
                BluetoothUnavailableView(.unknown)
            }
        }
    }
}


#Preview {
    NavigationStack {
        List {
            BluetoothUnavailableSection()
        }
    }
}
