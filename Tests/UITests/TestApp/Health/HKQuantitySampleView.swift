//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import Spezi
@_spi(TestingSupport) import SpeziDevices
import SpeziDevicesUI
import SpeziViews
import SwiftUI


struct HKQuantitySampleView: View {
    private let sample: HKQuantitySample

    var body: some View {
        VStack(alignment: .leading) {
            ListRow(sample.quantity.description) {
                Text(sample.startDate, style: .time)
            }
            if let device = sample.device, let name = device.name {
                Text(name)
                    .foregroundStyle(.secondary)
                    .font(.caption2)
            }
        }
    }

    init(_ sample: HKQuantitySample) {
        self.sample = sample
    }
}


#Preview {
    List {
        HKQuantitySampleView(HKQuantitySample.mockWeighSample)
    }
}

#Preview {
    List {
        HKQuantitySampleView(HKQuantitySample.mockBmiSample)
    }
}

#Preview {
    List {
        HKQuantitySampleView(HKQuantitySample.mockHeightSample)
    }
}

#Preview {
    List {
        HKQuantitySampleView(HKQuantitySample.mockHeartRateSample)
    }
}
