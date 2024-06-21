//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct DiscoveryView: View {
    var body: some View {
        PaneContent(
            title: "Discovering",
            subtitle: "Hold down the Bluetooth button for 3 seconds to put the device into pairing mode."
        ) {
            ProgressView()
                .controlSize(.large)
                .accessibilityHidden(true)
        }
    }
}


#if DEBUG
#Preview {
    SheetPreview {
        DiscoveryView()
    }
}
#endif
