//
// This source file is part of the ENGAGE-HF project based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport) import SpeziDevices
import SpeziViews
import SwiftUI


/// A sheet view displaying a newly recorded measurement.
///
/// Make sure to pass the ``ProcessedHealthMeasurement`` from the ``HealthMeasurements/newMeasurement``.
public struct MeasurementRecordedSheet: View {
    private let measurement: HealthKitMeasurement

    @Environment(HealthMeasurements.self) private var measurements
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewState = ViewState.idle

    @State private var dynamicDetent: PresentationDetent = .medium

    private var supportedTypeSize: ClosedRange<DynamicTypeSize> {
        switch measurement {
        case .weight:
            DynamicTypeSize.xSmall...DynamicTypeSize.accessibility4
        case .bloodPressure:
            DynamicTypeSize.xSmall...DynamicTypeSize.accessibility3
        }
    }

    public var body: some View {
        NavigationStack {
            PaneContent {
                Text("Measurement Recorded")
                    .font(.title)
                    .fixedSize(horizontal: false, vertical: true)
                // TODO: subtitle with the date of the measurement?
            } content: {
                // TODO: caoursel!
                MeasurementLayer(measurement: measurement)
            } action: {
                ConfirmMeasurementButton(viewState: $viewState) {
                    try await measurements.saveMeasurement()
                }
            }
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .task {
                                dynamicDetent = .height(proxy.size.height)
                            }
                    }
                }
                .viewStateAlert(state: $viewState)
                .interactiveDismissDisabled(viewState != .idle)
                .toolbar {
                    DismissButton()
                    /*ToolbarItem(placement: .cancellationAction) {
                     CloseButtonLayer(viewState: $viewState)
                     .disabled(viewState != .idle)
                     }*/
                }
                .dynamicTypeSize(supportedTypeSize)
        }
        .presentationDetents([dynamicDetent])
    }


    /// Create a new measurement sheet.
    /// - Parameter measurement: The processed measurement to display.
    public init(measurement: HealthKitMeasurement) {
        self.measurement = measurement
    }
}


#if DEBUG
#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementRecordedSheet(measurement: .weight(.mockWeighSample))
        }
        .previewWith(standard: TestMeasurementStandard()) {
            HealthMeasurements()
        }
}

#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementRecordedSheet(measurement: .weight(.mockWeighSample, bmi: .mockBmiSample, height: .mockHeightSample))
        }
        .previewWith(standard: TestMeasurementStandard()) {
            HealthMeasurements()
        }
}

#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementRecordedSheet(measurement: .bloodPressure(.mockBloodPressureSample, heartRate: .mockHeartRateSample))
        }
        .previewWith(standard: TestMeasurementStandard()) {
            HealthMeasurements()
        }
}
#endif
