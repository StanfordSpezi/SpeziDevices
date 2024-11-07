//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import SpeziDevices
import SpeziValidation
import SwiftUI


struct NameEditView: View {
    private let deviceInfo: PairedDeviceInfo
    private let save: (String) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State private var name: String

    @ValidationState private var validation

    var body: some View {
        List {
            VerifiableTextField("enter device name", text: $name)
                .validate(input: name, rules: [.nonEmpty, .deviceNameMaxLength])
                .receiveValidation(in: $validation)
                .autocapitalization(.words)
        }
            .navigationTitle(Text("Name", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    save(name)
                    dismiss()
                } label: {
                    Text("Done", bundle: .module)
                }
                    .disabled(deviceInfo.name == name || !validation.allInputValid)
            }
    }


    init(_ deviceInfo: PairedDeviceInfo, save: @escaping (String) -> Void) {
        self.deviceInfo = deviceInfo
        self.save = save
        self._name = State(wrappedValue: deviceInfo.name)
    }
}


extension ValidationRule {
    static var deviceNameMaxLength: ValidationRule {
        ValidationRule(rule: { input in
            input.count <= 50
        }, message: .init("The device name cannot be longer than 50 characters.", bundle: .atURL(from: .module)))
    }
}


#if DEBUG
#Preview {
    NavigationStack {
        NameEditView(PairedDeviceInfo(
            id: UUID(),
            deviceType: MockDevice.deviceTypeIdentifier,
            name: "Blood Pressure Monitor",
            model: "BP5250",
            batteryPercentage: 100
        )) { name in
            print("New Name is \(name)")
        }
    }
}
#endif
