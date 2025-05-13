//
// This source file is part of the Stanford Spezi open-project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
@_spi(TestingSupport)
import SpeziDevices
import SpeziViews
import SwiftUI


struct AccessoryImageView: View {
    private let device: any GenericDevice

    var body: some View {
        let image = icon?.image ?? Image(systemName: "sensor") // swiftlint:disable:this accessibility_label_for_image
        HStack {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .accessibilityHidden(true)
                .foregroundStyle(Color.accentColor) // set accent color if one uses sf symbols
                .symbolRenderingMode(.hierarchical) // set symbol rendering mode if one uses sf symbols
                .frame(maxWidth: 250, maxHeight: 120)
        }
            .frame(maxWidth: .infinity, maxHeight: 150) // make drag-able area a bit larger
            .background(Color(uiColor: .systemBackground)) // we need to set a non-clear color for it to be drag-able
    }

    private var icon: ImageReference? {
        switch device.appearance {
        case let .appearance(appearance):
            appearance.icon
        case let .variants(defaultAppearance, variants):
            if let variant = variants.first(where: { $0.criteria.matches(name: device.name, advertisementData: device.advertisementData) }) {
                variant.icon
            } else {
                defaultAppearance.icon
            }
        }
    }

    init(_ device: any GenericDevice) {
        self.device = device
    }
}


extension BluetoothDevice {
    fileprivate var appearance: DeviceAppearance {
        Self.appearance
    }
}


#if DEBUG
#Preview {
    AccessoryImageView(MockDevice.createMockDevice())
}
#endif
