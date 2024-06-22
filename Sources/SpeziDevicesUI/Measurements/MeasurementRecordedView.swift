//
// This source file is part of the ENGAGE-HF project based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziViews
#if DEBUG
@_spi(TestingSupport)
#endif
import SpeziDevices
import SwiftUI


struct MeasurementRecordedView: View { // TODO: Sheet!
    private let measurement: ProcessedHealthMeasurement

    @Environment(HealthMeasurements.self) private var measurements
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewState = ViewState.idle


    private var dynamicDetents: PresentationDetent {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return .fraction(0.35)
        case .medium, .large:
            return .fraction(0.45)
        case .xLarge, .xxLarge, .xxxLarge:
            return .fraction(0.65)
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return .large
        default:
            return .fraction(0.45)
        }
    }


    var body: some View {
        NavigationStack {
            VStack {
                MeasurementLayer(measurement: measurement)
                Spacer()
                ConfirmMeasurementButton(viewState: $viewState) {
                    try await measurements.saveMeasurement()
                }
            }
                .viewStateAlert(state: $viewState)
                .interactiveDismissDisabled(viewState != .idle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        CloseButtonLayer(viewState: $viewState)
                            .disabled(viewState != .idle)
                    }
                }
        }
            .presentationDetents([dynamicDetents])
    }


    init(measurement: ProcessedHealthMeasurement) {
        self.measurement = measurement
    }
}


#if DEBUG
#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementRecordedView(measurement: .weight(.mockWeighSample))
        }
        .previewWith(standard: TestMeasurementStandard()) {
            HealthMeasurements()
        }
}

#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementRecordedView(measurement: .bloodPressure(.mockBloodPressureSample, heartRate: .mockHeartRateSample))
        }
        .previewWith(standard: TestMeasurementStandard()) {
            HealthMeasurements()
        }
}
#endif
