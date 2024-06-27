//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
import OSLog
import Spezi
import SpeziBluetooth
import SpeziBluetoothServices
import SwiftUI


/// Manage and process health measurements from nearby Bluetooth Peripherals.
///
/// Use the `HealthMeasurements` module to collect health measurements from nearby Bluetooth Peripherals like connected weight scales or
/// blood pressure cuffs.
/// - Note: Implement your device as a [`BluetoothDevice`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetoothdevice)
///     using [SpeziBluetooth](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth).
///
/// To support `HealthMeasurements`, you need to adopt the ``HealthDevice`` protocol for your device.
/// One your device is loaded, register its measurement service with the `HealthMeasurements` module
/// by calling a suitable variant of `configureReceivingMeasurements(for:on:)`.
///
/// ```swift
/// import SpeziDevices
///
/// class MyDevice: HealthDevice {
///     @Service var deviceInformation = DeviceInformationService()
///     @Service var weightScale = WeightScaleService()
///
///     @Dependency private var measurements: HealthMeasurements?
///
///     required init() {}
///
///     func configure() {
///         measurements?.configureReceivingMeasurements(for: self, on: weightScale)
///     }
/// }
/// ```
///
/// To display new measurements to the user and save them to your external data store, you can use ``MeasurementRecordedSheet``.
/// Below is a short code example.
///
/// ```swift
/// import SpeziDevices
/// import SpeziDevicesUI
///
/// struct MyHomeView: View {
///     @Environment(HealthMeasurements.self) private var measurements
///
///     var body: some View {
///         @Bindable var measurements = measurements
///         ContentView()
///             .sheet(isPresented: $measurements.shouldPresentMeasurements) {
///                 MeasurementRecordedSheet { measurement in
///                     // handle saving the measurement
///                 }
///             }
///     }
/// }
/// ```
///
/// - Important: Don't forget to configure the `HealthMeasurements` module in
///     your [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate)
///
/// ## Topics
///
/// ### Configuring Health Measurements
/// - ``init()``
/// - ``init(_:)``
///
/// ### Register Devices
/// - ``configureReceivingMeasurements(for:on:)-8cbd0``
/// - ``configureReceivingMeasurements(for:on:)-87sgc``
///
/// ### Processing Measurements
/// - ``shouldPresentMeasurements``
/// - ``pendingMeasurements``
/// - ``discardMeasurement(_:)``
@Observable
public class HealthMeasurements {
    private let logger = Logger(subsystem: "ENGAGEHF", category: "HealthMeasurements")

    /// Determine if UI components displaying pending measurements should be displayed.
    @MainActor public var shouldPresentMeasurements = false
    /// The current queue of pending measurements.
    ///
    /// The newest measurement is always prepended.
    /// To clear pending measurements call ``discardMeasurement(_:)``.
    @MainActor public private(set) var pendingMeasurements: [HealthKitMeasurement] = []
    @MainActor @AppStorage @ObservationIgnored private var storedMeasurements: SavableDictionary<UUID, StoredMeasurement>

    @Dependency @ObservationIgnored private var bluetooth: Bluetooth?

    /// Initialize the Health Measurements Module.
    public required convenience init() {
        self.init("edu.stanford.spezi.SpeziDevices.HealthMeasurements.measurements-default")
    }

    /// Initialize the Health Measurements Module with custom storage key.
    /// - Parameter storageKey: The storage key for pending measurements.
    public init(_ storageKey: String) {
        self._storedMeasurements = AppStorage(wrappedValue: [:], storageKey)
    }

    /// Initialize the Health Measurements Module with mock measurements.
    /// - Parameter measurements: The list of measurements to inject.
    @_spi(TestingSupport)
    @MainActor
    public convenience init(mock measurements: [HealthKitMeasurement]) {
        self.init()
        self.pendingMeasurements = measurements
    }

    /// Clears all currently stored records on disk.
    @_spi(TestingSupport)
    @MainActor
    public func clearStorage() {
        storedMeasurements.removeAll()
        pendingMeasurements.removeAll()
    }

    /// Configure the Module.
    @_documentation(visibility: internal)
    public func configure() {
        Task.detached { @MainActor in
            for measurement in self.storedMeasurements.values {
                self.loadMeasurement(measurement.measurement, form: measurement.device)
            }
        }
    }

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
            await handleNewMeasurement(.weight(measurement, service.features ?? []), from: hkDevice)
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
            await handleNewMeasurement(.bloodPressure(measurement, service.features ?? []), from: hkDevice)
        }

        logger.debug("Registered device \(device.label), \(device.id) with HealthMeasurements")
    }

    @MainActor
    private func handleNewMeasurement(_ measurement: BluetoothHealthMeasurement, from source: HKDevice) {
        guard let healthKitMeasurement = loadMeasurement(measurement, form: source) else {
            return
        }

        storedMeasurements[healthKitMeasurement.id] = StoredMeasurement(measurement: measurement, device: source)

        shouldPresentMeasurements = true
    }

    @MainActor
    private func loadMeasurement(_ measurement: BluetoothHealthMeasurement, form source: HKDevice) -> HealthKitMeasurement? {
        let healthKitMeasurement: HealthKitMeasurement
        switch measurement {
        case let .weight(measurement, feature):
            let sample = measurement.weightSample(source: source, resolution: feature.weightResolution)
            let bmiSample = measurement.bmiSample(source: source)
            let heightSample = measurement.heightSample(source: source, resolution: feature.heightResolution)
            logger.debug("Measurement loaded: \(String(describing: measurement))")

            healthKitMeasurement = .weight(sample, bmi: bmiSample, height: heightSample)
        case let .bloodPressure(measurement, _):
            let bloodPressureSample = measurement.bloodPressureSample(source: source)
            let heartRateSample = measurement.heartRateSample(source: source)

            guard let bloodPressureSample else {
                logger.debug("Discarding invalid blood pressure measurement ...")
                return nil
            }

            logger.debug("Measurement loaded: \(String(describing: measurement))")

            healthKitMeasurement = .bloodPressure(bloodPressureSample, heartRate: heartRateSample)
        }

        // prepend to pending measurements
        pendingMeasurements.insert(healthKitMeasurement, at: 0)
        return healthKitMeasurement
    }

    /// Discard a pending measurement.
    ///
    /// Measurements are discarded if they are no longer of interest. Either because the users discarded the measurements contents or
    /// if the measurement was processed otherwise (e.g., saved to an external data store).

    /// - Parameter measurement: The pending measurement to discard.
    /// - Returns: Returns `true` if the measurement was in the array of pending measurement, `false` if nothing was discarded.
    @MainActor
    @discardableResult
    public func discardMeasurement(_ measurement: HealthKitMeasurement) -> Bool {
        guard let index = self.pendingMeasurements.firstIndex(where: { $0.id == measurement.id }) else {
            return false
        }
        let element = self.pendingMeasurements.remove(at: index)
        
        storedMeasurements.removeValue(forKey: element.id)
        return true
    }
}


extension HealthMeasurements: Module, EnvironmentAccessible, DefaultInitializable {}


extension HealthMeasurements {
    /// Call in preview simulator wrappers.
    ///
    /// Loads a mock measurement to display in preview.
    @_spi(TestingSupport)
    @MainActor
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
    @MainActor
    public func loadMockBloodPressureMeasurement() {
        let device = MockDevice.createMockDevice()

        guard let measurement = device.bloodPressure.bloodPressureMeasurement else {
            preconditionFailure("Mock Blood Pressure Measurement was never injected!")
        }

        handleNewMeasurement(.bloodPressure(measurement, device.bloodPressure.features ?? []), from: device.hkDevice)
    }
}
