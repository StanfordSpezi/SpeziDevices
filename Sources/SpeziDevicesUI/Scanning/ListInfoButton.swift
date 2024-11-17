//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


public struct ListInfoButton: View { // TODO: move to SpeziViews!
    private let label: Text
    private let action: () -> Void

    public var body: some View {
        Button(action: action) {
            Label {
                label
            } icon: {
                Image(systemName: "info.circle") // swiftlint:disable:this accessibility_label_for_image
            }
        }
            .labelStyle(.iconOnly)
            .font(.title3)
            .foregroundColor(.accentColor)
            .buttonStyle(.plain) // ensure button is clickable next to the other button
            .accessibilityAction(named: label, action)
#if TEST || targetEnvironment(simulator)
            .accessibilityHidden(true) // accessibility actions cannot be unit tested
#endif
    }

    public init(_ label: Text, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public init(_ resource: LocalizedStringResource, action: @escaping () -> Void) {
        self.label = Text(resource)
        self.action = action
    }
}
