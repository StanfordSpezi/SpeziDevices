//
// This source file is part of the ENGAGE-HF project based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import OSLog
import Spezi
import SpeziBluetooth
import SpeziBluetoothServices


/// Manage and process incoming health measurements.
///
/// ## Topics
///
/// ### Register Devices
/// - ``configureReceivingMeasurements(for:on:)-8cbd0``
/// - ``configureReceivingMeasurements(for:on:)-87sgc``
@Observable
public class HealthMeasurements { // TODO: code example?
    private let logger = Logger(subsystem: "ENGAGEHF", category: "HealthMeasurements")

    // TODO: measurement is just discarded if the sheet closes?
    // TODO: support array of new measurements? (item binding needs write access :/) => carousel?
    // TODO: support long term storage
    public var newMeasurement: HealthKitMeasurement?

    @StandardActor @ObservationIgnored private var standard: any HealthMeasurementsConstraint
    @Dependency @ObservationIgnored private var bluetooth: Bluetooth?

    /// Initialize the Health Measurements Module.
    public required init() {}

    /// Configure receiving and processing weight measurements from the provided service.
    ///
    /// Configures the device's weight measurements to be processed by the Health Measurements module.
    ///
    /// - Parameters:
    ///   - device: The device on which the service is present.
    ///   - service: The Weight Scale service to register.
    public func configureReceivingMeasurements<Device: HealthDevice>(for device: Device, on service: WeightScaleService) {
        let hkDevice = device.hkDevice

        // make sure to not capture the device
        service.$weightMeasurement.onChange { [weak self, weak service] measurement in
            guard let self, let service else {
                return
            }
            logger.debug("Received new weight measurement: \(String(describing: measurement))")
            handleNewMeasurement(.weight(measurement, service.features ?? []), from: hkDevice)
        }
    }

    /// Configure receiving and processing blood pressure measurements form the provided service.
    ///
    /// Configures the device's blood pressure measurements to be processed by the Health Measurements module.
    ///
    /// - Parameters:
    ///   - device: The device on which the service is present.
    ///   - service: The Blood Pressure service to register.
    public func configureReceivingMeasurements<Device: HealthDevice>(for device: Device, on service: BloodPressureService) {
        let hkDevice = device.hkDevice

        // make sure to not capture the device
        service.$bloodPressureMeasurement.onChange { [weak self, weak service] measurement in
            guard let self, let service else {
                return
            }
            logger.debug("Received new blood pressure measurement: \(String(describing: measurement))")
            handleNewMeasurement(.bloodPressure(measurement, service.features ?? []), from: hkDevice)
        }
    }

    private func handleNewMeasurement(_ measurement: BluetoothHealthMeasurement, from source: HKDevice) {
        switch measurement {
        case let .weight(measurement, feature):
            let sample = measurement.weightSample(source: source, resolution: feature.weightResolution)
            let bmiSample = measurement.bmiSample(source: source)
            let heightSample = measurement.heightSample(source: source, resolution: feature.heightResolution)
            logger.debug("Measurement loaded: \(String(describing: measurement))")

            newMeasurement = .weight(sample, bmi: bmiSample, height: heightSample)
        case let .bloodPressure(measurement, _):
            let bloodPressureSample = measurement.bloodPressureSample(source: source)
            let heartRateSample = measurement.heartRateSample(source: source)

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

        handleNewMeasurement(.weight(measurement, device.weightScale.features ?? []), from: device.hkDevice)
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

        handleNewMeasurement(.bloodPressure(measurement, device.bloodPressure.features ?? []), from: device.hkDevice)
    }
}
#endif
