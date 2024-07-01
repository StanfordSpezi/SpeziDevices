//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import ACarousel
import HealthKit
import OSLog
@_spi(TestingSupport) import SpeziDevices
import SpeziViews
import SwiftUI


/// A sheet view displaying a newly recorded measurement.
///
/// This view retrieves the pending measurements from the ``HealthMeasurements`` Module that is present in the SwiftUI environment.
public struct MeasurementRecordedSheet: View {
    private let logger = Logger(subsystem: "edu.stanford.spezi.SpeziDevices", category: "MeasurementRecordedSheet")
    private let saveSamples: ([HKSample]) async throws -> Void

    @Environment(HealthMeasurements.self) private var measurements
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedMeasurement: HealthKitMeasurement?

    @State private var viewState = ViewState.idle
    @State private var dynamicDetent: PresentationDetent = .medium

    @MainActor
    private var forcedUnwrappedMeasurement: Binding<HealthKitMeasurement> {
        Binding {
            guard let selectedMeasurement else {
                guard let selectedMeasurement = measurements.pendingMeasurements.first else {
                    preconditionFailure("Entered code path where selectedMeasurement was not set.")
                }
                self.selectedMeasurement = selectedMeasurement
                return selectedMeasurement
            }
            return selectedMeasurement
        } set: { newValue in
            selectedMeasurement = newValue
        }

    }

    @MainActor private var supportedTypeSize: ClosedRange<DynamicTypeSize> {
        let upperBound: DynamicTypeSize = switch selectedMeasurement {
        case .weight:
            .accessibility4
        case .bloodPressure:
            .accessibility3
        case nil:
            .accessibility5
        }

        return DynamicTypeSize.xSmall...upperBound
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
                        .dynamicTypeSize(supportedTypeSize)
                }
            }
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .task {
                                // TODO: doesn't work?
                                dynamicDetent = .height(proxy.size.height)
                            }
                    }
                }
                .toolbar {
                    DismissButton()
                }
        }
            .presentationDetents([dynamicDetent])
            .presentationCornerRadius(25)
    }


    @ViewBuilder @MainActor private var content: some View {
        if measurements.pendingMeasurements.count > 1 {
            TabView(selection: forcedUnwrappedMeasurement) {
                ForEach(measurements.pendingMeasurements) { measurement in
                    MeasurementLayer(measurement: measurement)
                        .padding(.bottom, 35)
                        .tag(measurement)
                }
            }
                .scaledToFill()
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

            measurements.discardMeasurement(selectedMeasurement)

            logger.info("Saved measurement: \(String(describing: selectedMeasurement))")
            dismiss() // TODO: maintain to show last measurement when dismissing!
        } discard: {
            guard let selectedMeasurement else {
                return
            }
            measurements.discardMeasurement(selectedMeasurement)

            if measurements.pendingMeasurements.isEmpty {
                dismiss() // TODO: maintain to show last measurement when dismissing!
            }
        }
    }


    /// Create a new measurement sheet.
    public init(save saveSamples: @escaping ([HKSample]) async throws -> Void) {
        self.saveSamples = saveSamples
    }
}


#if DEBUG
#Preview {
    Text(verbatim: "")
        .sheet(isPresented: .constant(true)) {
            MeasurementRecordedSheet { samples in
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
            MeasurementRecordedSheet { samples in
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
            MeasurementRecordedSheet { samples in
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
            MeasurementRecordedSheet { samples in
                print("Saving samples \(samples)")
            }
                .dynamicTypeSize(.accessibility3)
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
            MeasurementRecordedSheet { samples in
                print("Saving samples \(samples)")
            }
        }
        .previewWith {
            HealthMeasurements()
        }
}
#endif
