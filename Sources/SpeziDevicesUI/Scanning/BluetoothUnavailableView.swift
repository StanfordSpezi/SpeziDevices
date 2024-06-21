//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SwiftUI


public struct BluetoothUnavailableView: View { // TODO: missing docs on views!
    private let state: BluetoothState

    private var titleMessage: LocalizedStringResource? {
        switch state {
        case .poweredOn:
            return nil
        case .poweredOff:
            return .init("Bluetooth Off", bundle: .atURL(from: .module))
        case .unauthorized:
            return .init("Bluetooth Prohibited", bundle: .atURL(from: .module))
        case .unsupported:
            return .init("Bluetooth Unsupported", bundle: .atURL(from: .module))
        case .unknown:
            return .init("Bluetooth Failure", bundle: .atURL(from: .module))
        }
    }

    private var subtitleMessage: LocalizedStringResource? {
        switch state {
        case .poweredOn:
            return nil
        case .poweredOff:
            return .init("Bluetooth is turned off. ...", bundle: .atURL(from: .module))
        case .unauthorized:
            return .init("Bluetooth is required to make connections to nearby devices. ...", bundle: .atURL(from: .module))
        case .unknown:
            return .init("We have trouble with the Bluetooth communication. Please try again.", bundle: .atURL(from: .module))
        case .unsupported:
            return .init("Bluetooth is unsupported on this device!", bundle: .atURL(from: .module))
        }
    }


    public var body: some View {
        if titleMessage != nil || subtitleMessage != nil {
            ContentUnavailableView {
                if let titleMessage {
                    Label {
                        Text(titleMessage)
                    } icon: {
                        EmptyView()
                    }
                }
            } description: {
                if let subtitleMessage {
                    Text(subtitleMessage)
                }
            } actions: {
                switch state {
                case .poweredOff, .unauthorized:
                    #if os(iOS) || os(visionOS) || os(tvOS)
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) { // TODO: this is wrong?
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Open Settings", bundle: .module)
                    }
                    #else
                    EmptyView()
                    #endif
                default:
                    EmptyView()
                }
            }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: -15, leading: 0, bottom: 0, trailing: 0))
        } else {
            EmptyView()
        }
    }


    public init(_ state: BluetoothState) {
        self.state = state
    }
}


#if DEBUG
#Preview {
    GeometryReader { proxy in
        List {
            BluetoothUnavailableView(.poweredOff)
                .frame(height: proxy.size.height - 100)
        }
    }
}

#Preview {
    GeometryReader { proxy in
        List {
            BluetoothUnavailableView(.unauthorized)
                .frame(height: proxy.size.height - 100)
        }
    }
}

#Preview {
    GeometryReader { proxy in
        List {
            BluetoothUnavailableView(.unsupported)
                .frame(height: proxy.size.height - 100)
        }
    }
}

#Preview {
    GeometryReader { proxy in
        List {
            BluetoothUnavailableView(.unknown)
                .frame(height: proxy.size.height - 100)
        }
    }
}
#endif
