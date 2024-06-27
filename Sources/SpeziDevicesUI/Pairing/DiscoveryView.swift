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
            Text("Discovering")
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

    init(pairingHint: Text) where Hint == Text {
        self.init {
            pairingHint
        }
    }

    init(pairingHint: LocalizedStringResource) where Hint == Text {
        self.init(pairingHint: Text(pairingHint))
    }
}


#if DEBUG
#Preview {
    SheetPreview {
        DiscoveryView()
    }
}
#endif
