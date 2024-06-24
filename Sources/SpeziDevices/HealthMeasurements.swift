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
import SpeziBluetoothServices


/// Manage and process incoming health measurements.
@Observable
public class HealthMeasurements { // TODO: code example?
    private let logger = Logger(subsystem: "ENGAGEHF", category: "HealthMeasurements")

    // TODO: measurement is just discarded if the sheet closes?
    // TODO: support array of new measurements? (item binding needs write access :/) => carousel?
    // TODO: support long term storage
    public var newMeasurement: HealthKitMeasurement?

    @StandardActor @ObservationIgnored private var standard: any HealthMeasurementsConstraint
    @Dependency @ObservationIgnored private var bluetooth: Bluetooth?

    required public init() {}

    public func configureReceivingMeasurements<Device: HealthDevice>(for device: Device, on service: WeightScaleService) {
        service.$weightMeasurement.onChange { [weak self, weak device, weak service] measurement in
            guard let device, let service else {
                return
            }
            self?.handleNewMeasurement(.weight(measurement, service.features ?? []), from: device)
        }
    }

    public func configureReceivingMeasurements<Device: HealthDevice>(for device: Device, on service: BloodPressureService) {
        service.$bloodPressureMeasurement.onChange { [weak self, weak device, weak service] measurement in
            guard let device, let service else {
                return
            }
            self?.handleNewMeasurement(.bloodPressure(measurement, service.features ?? []), from: device)
        }
    }

    // TODO: rename! make private?
    public func handleNewMeasurement<Device: HealthDevice>(_ measurement: BluetoothHealthMeasurement, from device: Device) {
        let hkDevice = device.hkDevice

        switch measurement {
        case let .weight(measurement, feature):
            let sample = measurement.weightSample(source: hkDevice, resolution: feature.weightResolution)
            let bmiSample = measurement.bmiSample(source: hkDevice)
            let heightSample = measurement.heightSample(source: hkDevice, resolution: feature.heightResolution)
            logger.debug("Measurement loaded: \(String(describing: measurement))")

            newMeasurement = .weight(sample, bmi: bmiSample, height: heightSample)
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

    // TODO: make it closure based???? way better!
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
            try await standard.addMeasurement(samples: measurement.samples)
        } catch {
            logger.error("Failed to save measurement samples: \(error)")
            throw error
        }

        logger.info("Save successful!")
        newMeasurement = nil
    }
}


extension HealthMeasurements: Module, EnvironmentAccessible, DefaultInitializable {}


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
