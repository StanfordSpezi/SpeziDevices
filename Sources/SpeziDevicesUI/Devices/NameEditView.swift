//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport) import SpeziDevices
import SpeziValidation
import SwiftUI


struct NameEditView: View {
    private let deviceInfo: PairedDeviceInfo
    private let save: (String) -> Void

    // TODO: @Environment(\.dismiss) private var dismiss

    @State private var name: String

    @ValidationState private var validation

    var body: some View {
        List {
            VerifiableTextField("enter device name", text: $name)
                .validate(input: name, rules: [.nonEmpty, .deviceNameMaxLength])
                .receiveValidation(in: $validation)
                .autocapitalization(.words)
        }
            .navigationTitle("Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") {
                    save(name)
                    // TODO: dismiss()
                }
                    .disabled(deviceInfo.name == name || !validation.allInputValid)
            }
    }


    init(_ deviceInfo: PairedDeviceInfo, save: @escaping (String) -> Void) {
        let name = deviceInfo.name
        self.deviceInfo = deviceInfo
        self.save = save
        self._name = State(wrappedValue: name)
    }
}


extension ValidationRule {
    static var deviceNameMaxLength: ValidationRule {
        ValidationRule(rule: { input in
            input.count <= 50
        }, message: "The device name cannot be longer than 50 characters.")
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
            icon: .asset("Omron-BP5250"),
            batteryPercentage: 100
        )) { name in
            print("New Name is \(name)")
        }
    }
}
#endif
