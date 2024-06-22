//
// This source file is part of the ENGAGE-HF project based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OSLog
import Spezi
import SpeziBluetooth


/// Manage and process incoming health measurements.
@Observable
public class HealthMeasurements: Module, EnvironmentAccessible, DefaultInitializable {
    private let logger = Logger(subsystem: "ENGAGEHF", category: "HealthMeasurements")

    public private(set) var newMeasurement: ProcessedHealthMeasurement? // TODO: support array of new measurements?

    @StandardActor @ObservationIgnored private var standard: any HealthMeasurementsConstraint
    @Dependency @ObservationIgnored private var bluetooth: Bluetooth?

    required public init() {}

    // TODO: rename!
    public func handleNewMeasurement<Device: HealthDevice>(_ measurement: HealthMeasurement, from device: Device) {
        let hkDevice = device.hkDevice

        switch measurement {
        case let .weight(measurement, feature):
            let sample = measurement.quantitySample(source: hkDevice, resolution: feature.weightResolution)
            logger.debug("Measurement loaded: \(measurement.weight)")

            newMeasurement = .weight(sample)
        case let .bloodPressure(measurement, _):
            let bloodPressureSample = measurement.bloodPressureSample(source: hkDevice)
            let heartRateSample = measurement.heartRateSample(source: hkDevice)

            guard let bloodPressureSample else {
                logger.debug("Discarding invalid blood pressure measurement ...")
                return
            }

            logger.debug("Measurement loaded: \(String(describing: measurement))")

            newMeasurement = .bloodPressure(bloodPressureSample, heartRate: heartRateSample)
        }
    }

    // TODO: docs everywhere!

    public func saveMeasurement() async throws { // TODO: rename?
        if ProcessInfo.processInfo.isPreviewSimulator {
            try await Task.sleep(for: .seconds(5))
            return
        }
        
        guard let measurement = self.newMeasurement else {
            logger.error("Attempting to save a nil measurement.")
            return
        }

        logger.info("Saving the following measurement: \(String(describing: measurement))")
        do {
            switch measurement {
            case let .weight(sample):
                try await standard.addMeasurement(sample: sample)
            case let .bloodPressure(bloodPressureSample, heartRateSample):
                try await standard.addMeasurement(sample: bloodPressureSample)
                if let heartRateSample {
                    try await standard.addMeasurement(sample: heartRateSample)
                }
            }
        } catch {
            logger.error("Failed to save measurement samples: \(error)")
            throw error
        }

        logger.info("Save successful!")
        newMeasurement = nil
    }
}


#if DEBUG || TEST
extension HealthMeasurements {
    /// Call in preview simulator wrappers.
    ///
    /// Loads a mock measurement to display in preview.
    @_spi(TestingSupport)
    public func loadMockWeightMeasurement() {
        let device = MockDevice.createMockDevice()

        guard let measurement = device.weightScale.weightMeasurement else {
            preconditionFailure("Mock Weight Measurement was never injected!")
        }

        handleNewMeasurement(.weight(measurement, device.weightScale.features ?? []), from: device)
    }

    /// Call in preview simulator wrappers.
    ///
    /// Loads a mock measurement to display in preview.
    @_spi(TestingSupport)
    public func loadMockBloodPressureMeasurement() {
        let device = MockDevice.createMockDevice()

        guard let measurement = device.bloodPressure.bloodPressureMeasurement else {
            preconditionFailure("Mock Blood Pressure Measurement was never injected!")
        }

        handleNewMeasurement(.bloodPressure(measurement, device.bloodPressure.features ?? []), from: device)
    }
}
#endif
