//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
@_spi(TestingSupport) import SpeziDevices
import SwiftUI


public struct PeripheralLabel: View {
    private let peripheral: any GenericBluetoothPeripheral

    public var body: some View {
        Text(peripheral.label)
            .accessibilityLabel(Text(peripheral.accessibilityLabel))
    }

    init(_ peripheral: any GenericBluetoothPeripheral) {
        self.peripheral = peripheral
    }
}


#if DEBUG
#Preview {
    List {
        PeripheralLabel(MockBluetoothPeripheral(label: "MyDevice 1", state: .connected))
    }
}
#endif
