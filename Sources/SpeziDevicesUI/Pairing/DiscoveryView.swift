//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct DiscoveryView<Hint: View>: View {
    private let pairingHint: Hint

    var body: some View {
        PaneContent {
            Text("Discovering", bundle: .module)
        } subtitle: {
            pairingHint
        } content: {
            ProgressView()
                .controlSize(.large)
                .accessibilityHidden(true)
        }
    }

    init(@ViewBuilder pairingHint: () -> Hint = { EmptyView() }) {
        self.pairingHint = pairingHint()
    }
}


#if DEBUG
#Preview {
    SheetPreview {
        DiscoveryView()
    }
}
#endif
