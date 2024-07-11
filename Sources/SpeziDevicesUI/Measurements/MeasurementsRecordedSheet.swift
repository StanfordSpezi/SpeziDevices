//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import OSLog
@_spi(TestingSupport) import SpeziDevices
import SpeziViews
import SwiftUI


/// A sheet view displaying one or many newly recorded measurements.
///
/// This view retrieves the pending measurements from the [`HealthMeasurements`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevices/healthmeasurements)
/// Module that is present in the SwiftUI environment.
public struct MeasurementsRecordedSheet: View {
    private let logger = Logger(subsystem: "edu.stanford.spezi.SpeziDevices", category: "MeasurementsRecordedSheet")
    private let saveSamples: @MainActor ([HKSample]) async throws -> Void

    @Environment(HealthMeasurements.self) private var measurements
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedMeasurement: HealthKitMeasurement?

    @State private var viewState = ViewState.idle

    @MainActor private var forcedUnwrappedMeasurement: Binding<HealthKitMeasurement> {
        Binding {
            guard let selectedMeasurement = selectedMeasurement ?? measurements.pendingMeasurements.first else {
                preconditionFailure("Entered code path where selectedMeasurement was not set.")
            }
            return selectedMeasurement
        } set: { newValue in
            selectedMeasurement = newValue
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if measurements.pendingMeasurements.isEmpty {
                    ContentUnavailableView(
                        "No Pending Measurements",
                        systemImage: "heart.text.square",
                        description: Text("There are currently no pending measurements. Conduct a measurement with a paired device while nearby.")
                    )
                } else {
                    PaneContent {
                        Text("Measurement Recorded")
                            .font(.title)
                            .fixedSize(horizontal: false, vertical: true)
                    } subtitle: {
                        EmptyView()
                    } content: {
                        content
                    } action: {
                        action
                    }
                        .viewStateAlert(state: $viewState)
                        .interactiveDismissDisabled(viewState != .idle)
                        .dynamicTypeSize(.xSmall...DynamicTypeSize.accessibility3)
                        .onChange(of: selectedMeasurement, initial: true) {
                            if selectedMeasurement == nil {
                                selectedMeasurement = measurements.pendingMeasurements.first
                            }
                        }
                }
            }
                .toolbar {
                    DismissButton()
                }
        }
            .presentationDetents([.fraction(0.45), .fraction(0.6), .large])
            .presentationCornerRadius(25)
    }


    @ViewBuilder @MainActor private var content: some View {
        if measurements.pendingMeasurements.count > 1 {
            TabView(selection: forcedUnwrappedMeasurement) {
                ForEach(measurements.pendingMeasurements) { measurement in
                    VStack {
                        MeasurementLayer(measurement: measurement)
                        Spacer()
                            .frame(minHeight: 30, idealHeight: 45, maxHeight: 60)
                            .fixedSize()
                    }
                        .tag(measurement)
                }
            }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
        } else if let measurement = measurements.pendingMeasurements.first {
            MeasurementLayer(measurement: measurement)
        }
    }

    @ViewBuilder @MainActor private var action: some View {
        ConfirmMeasurementButton(viewState: $viewState) {
            guard let selectedMeasurement else {
                return
            }

            do {
                try await saveSamples(selectedMeasurement.samples)
            } catch {
                logger.error("Failed to save measurement samples: \(error)")
                throw error
            }


            logger.info("Saved measurement: \(String(describing: selectedMeasurement))")
            dismiss()

            discardSelectedMeasurement(selectedMeasurement)
        } discard: {
            guard let selectedMeasurement else {
                return
            }

            if measurements.pendingMeasurements.isEmpty {
                dismiss()
            }

            discardSelectedMeasurement(selectedMeasurement)
        }
    }


    /// Create a new measurement sheet.
    public init(save saveSamples: @MainActor @escaping ([HKSample]) async throws -> Void) {
        self.saveSamples = saveSamples
    }


    @MainActor
    private func discardSelectedMeasurement(_ measurement: HealthKitMeasurement) {
        guard let index = measurements.pendingMeasurements.firstIndex(of: measurement) else {
            return
        }

        measurements.discardMeasurement(measurement)
        if index >= measurements.pendingMeasurements.count {
            selectedMeasurement = measurements.pendingMeasurements.last
        } else {
            selectedMeasurement = measurements.pendingMeasurements[index]
        }
    }
}


#if DEBUG
#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementsRecordedSheet { samples in
                print("Saving samples \(samples)")
            }
        }
        .previewWith {
            HealthMeasurements(mock: [.weight(.mockWeighSample)])
        }
}

#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementsRecordedSheet { samples in
                print("Saving samples \(samples)")
            }
        }
        .previewWith {
            HealthMeasurements(mock: [.weight(.mockWeighSample, bmi: .mockBmiSample, height: .mockHeightSample)])
        }
}

#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementsRecordedSheet { samples in
                print("Saving samples \(samples)")
            }
        }
        .previewWith {
            HealthMeasurements(mock: [.bloodPressure(.mockBloodPressureSample, heartRate: .mockHeartRateSample)])
        }
}

#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementsRecordedSheet { samples in
                print("Saving samples \(samples)")
            }
        }
        .previewWith {
            HealthMeasurements(mock: [
                .weight(.mockWeighSample, bmi: .mockBmiSample, height: .mockHeightSample),
                .bloodPressure(.mockBloodPressureSample, heartRate: .mockHeartRateSample),
                .weight(.mockWeighSample)
            ])
        }
}

#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementsRecordedSheet { samples in
                print("Saving samples \(samples)")
            }
        }
        .previewWith {
            HealthMeasurements()
        }
}
#endif
