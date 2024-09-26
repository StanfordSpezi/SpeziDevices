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


import AccessorySetupKit
@available(iOS 18, *)
struct AccessoryRenameButton: View {
    private let accessory: ASAccessory

    @State private var buttonPressed: Bool = false
    @State private var viewState: ViewState = .idle
    @State private var buttonDebounce: Task<Void, Never>? {
        willSet {
            buttonDebounce?.cancel()
        }
    }
    @State private var renameTask: Task<Void, Never>? {
        willSet {
            renameTask?.cancel()
        }
    }

    @Environment(PairedDevices.self) private var pairedDevices

    private var buttonBackground: (some View)? {
        if buttonPressed {
            Rectangle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Color(uiColor: .systemGray4)
                )
                .foregroundStyle(.clear)
        } else {
            nil
        }
    }

    var body: some View {
        Group { // swiftlint:disable:this closure_body_length
            if pairedDevices.accessoryPickerPresented {
                HStack {
                    LabeledContent("Name") {
                        Text(accessory.displayName)
                    }
                    Spacer()
                    ProgressView()
                        .padding(.trailing, -10) // make sure content still right aligns
                        .accessibilityRemoveTraits(.updatesFrequently)
                }
            } else {
                NavigationLink {
                    EmptyView()
                } label: {
                    // TODO: is button necessary?
                    LabeledContent {
                        Text(accessory.displayName)
                            .foregroundStyle(.secondary)
                    } label: {
                        Text("Name", bundle: .module)
                    }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !buttonPressed else {
                                return
                            }

                            buttonPressed = true
                            renameAccessory()

                            buttonDebounce = Task {
                                try? await Task.sleep(for: .milliseconds(75))
                                buttonPressed = false
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.5, maximumDistance: .infinity) {
                            renameAccessory()
                        } onPressingChanged: { pressing in
                            buttonPressed = pressing
                        }
                }
                    .listRowBackground(buttonBackground)
            }
        }
            .viewStateAlert(state: $viewState)
    }

    init(accessory: ASAccessory) {
        self.accessory = accessory
    }

    private func renameAccessory() {
        guard renameTask == nil else {
            return
        }

        renameTask = Task {
            defer {
                renameTask = nil
            }
            do {
                try await pairedDevices.renameAccessory(for: accessory)
            } catch {
                viewState = .error(AnyLocalizedError(
                    error: error,
                    defaultErrorDescription: .init("Failed to rename accessory", bundle: .atURL(from: .module))
                ))
            }
        }
    }
}


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
