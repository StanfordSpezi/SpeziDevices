//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import HealthKit
@_spi(TestingSupport)
import SpeziBluetooth
import SpeziBluetoothServices
@_spi(TestingSupport)
@testable import SpeziDevices
import XCTest


final class HealthMeasurementsTests: XCTestCase {
    @MainActor
    func testReceivingWeightMeasurements() async throws {
        let device = MockDevice.createMockDevice(state: .connecting, weightMeasurement: .mock(additionalInfo: .init(bmi: 230, height: 1790)))
        let measurements = HealthMeasurements()

        measurements.configureReceivingMeasurements(for: device, on: \.weightScale)

        // just inject the same value again to trigger on change!
        let measurement = try XCTUnwrap(device.weightScale.weightMeasurement)
        device.weightScale.$weightMeasurement.inject(measurement) // first measurement should be ignored in connecting state!

        try await Task.sleep(for: .milliseconds(50))
        device.$state.inject(.connected)
        device.weightScale.$weightMeasurement.inject(measurement)

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(measurements.shouldPresentMeasurements)
        XCTAssertEqual(measurements.pendingMeasurements.count, 1)

        let weightMeasurement = try XCTUnwrap(measurements.pendingMeasurements.first)
        guard case let .weight(sample, bmi0, height0) = weightMeasurement else {
            XCTFail("Unexpected type of measurement: \(weightMeasurement)")
            return
        }

        let bmi = try XCTUnwrap(bmi0)
        let height = try XCTUnwrap(height0)
        let expectedDate = try XCTUnwrap(device.weightScale.weightMeasurement?.timeStamp?.date)

        XCTAssertEqual(weightMeasurement.samples, [sample, bmi, height])

        XCTAssertEqual(sample.quantityType, HKQuantityType(.bodyMass))
        XCTAssertEqual(sample.startDate, expectedDate)
        XCTAssertEqual(sample.endDate, sample.startDate)
        XCTAssertEqual(sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), 42.0)
        XCTAssertEqual(sample.device?.name, "Mock Device")


        XCTAssertEqual(bmi.quantityType, HKQuantityType(.bodyMassIndex))
        XCTAssertEqual(bmi.startDate, expectedDate)
        XCTAssertEqual(bmi.endDate, sample.startDate)
        XCTAssertEqual(bmi.quantity.doubleValue(for: .count()), 23)
        XCTAssertEqual(bmi.device?.name, "Mock Device")

        XCTAssertEqual(height.quantityType, HKQuantityType(.height))
        XCTAssertEqual(height.startDate, expectedDate)
        XCTAssertEqual(height.endDate, sample.startDate)
        XCTAssertEqual(height.quantity.doubleValue(for: .meterUnit(with: .centi)), 179.0)
        XCTAssertEqual(height.device?.name, "Mock Device")
    }

    @MainActor
    func testReceivingBloodPressureMeasurements() async throws {
        let device = MockDevice.createMockDevice(state: .connected)
        let measurements = HealthMeasurements()

        measurements.configureReceivingMeasurements(for: device, on: \.bloodPressure)

        // just inject the same value again to trigger on change!
        let measurement = try XCTUnwrap(device.bloodPressure.bloodPressureMeasurement)
        device.bloodPressure.$bloodPressureMeasurement.inject(measurement)

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(measurements.shouldPresentMeasurements)
        XCTAssertEqual(measurements.pendingMeasurements.count, 1)

        let bloodPressureMeasurement = try XCTUnwrap(measurements.pendingMeasurements.first)
        guard case let .bloodPressure(sample, heartRate0) = bloodPressureMeasurement else {
            XCTFail("Unexpected type of measurement: \(bloodPressureMeasurement)")
            return
        }

        let heartRate = try XCTUnwrap(heartRate0)
        let expectedDate = try XCTUnwrap(device.weightScale.weightMeasurement?.timeStamp?.date)

        XCTAssertEqual(bloodPressureMeasurement.samples, [sample, heartRate])


        XCTAssertEqual(heartRate.quantityType, HKQuantityType(.heartRate))
        XCTAssertEqual(heartRate.startDate, expectedDate)
        XCTAssertEqual(heartRate.endDate, sample.startDate)
        XCTAssertEqual(heartRate.quantity.doubleValue(for: .count().unitDivided(by: .minute())), 62)
        XCTAssertEqual(heartRate.device?.name, "Mock Device")

        XCTAssertEqual(sample.objects.count, 2)
        let systolic = try XCTUnwrap(sample.objects(for: HKQuantityType(.bloodPressureSystolic)).first as? HKQuantitySample)
        let diastolic = try XCTUnwrap(sample.objects(for: HKQuantityType(.bloodPressureDiastolic)).first as? HKQuantitySample)

        XCTAssertEqual(systolic.quantityType, HKQuantityType(.bloodPressureSystolic))
        XCTAssertEqual(systolic.startDate, expectedDate)
        XCTAssertEqual(systolic.endDate, sample.startDate)
        XCTAssertEqual(systolic.quantity.doubleValue(for: .millimeterOfMercury()), 103.0)
        XCTAssertEqual(systolic.device?.name, "Mock Device")

        XCTAssertEqual(diastolic.quantityType, HKQuantityType(.bloodPressureDiastolic))
        XCTAssertEqual(diastolic.startDate, expectedDate)
        XCTAssertEqual(diastolic.endDate, sample.startDate)
        XCTAssertEqual(diastolic.quantity.doubleValue(for: .millimeterOfMercury()), 64.0)
        XCTAssertEqual(diastolic.device?.name, "Mock Device")
    }

    @MainActor
    func testMeasurementStorage() async throws {
        let measurements = HealthMeasurements()

        measurements.configure() // init model container
        try await Task.sleep(for: .milliseconds(50))

        measurements.loadMockWeightMeasurement()
        measurements.loadMockBloodPressureMeasurement()

        XCTAssertEqual(measurements.pendingMeasurements.count, 2)

        try measurements.refreshFetchingMeasurements() // clear pending measurements and fetch again from storage
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(measurements.pendingMeasurements.count, 2)
        // tests that order stays same over storage retrieval

        // Restoring from disk doesn't preserve HealthKit UUIDs
        guard case .bloodPressure = measurements.pendingMeasurements.first,
              case .weight = measurements.pendingMeasurements.last else {
            XCTFail("Order of measurements doesn't match: \(measurements.pendingMeasurements)")
            return
        }
    }

    @MainActor
    func testDiscardingMeasurements() async throws {
        let device = MockDevice.createMockDevice(state: .connected)
        let measurements = HealthMeasurements()

        measurements.configureReceivingMeasurements(for: device, on: \.bloodPressure)
        measurements.configureReceivingMeasurements(for: device, on: \.weightScale)

        let measurement1 = try XCTUnwrap(device.weightScale.weightMeasurement)
        device.weightScale.$weightMeasurement.inject(measurement1)

        try await Task.sleep(for: .milliseconds(50))

        let measurement0 = try XCTUnwrap(device.bloodPressure.bloodPressureMeasurement)
        device.bloodPressure.$bloodPressureMeasurement.inject(measurement0)

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(measurements.shouldPresentMeasurements)
        XCTAssertEqual(measurements.pendingMeasurements.count, 2)

        let bloodPressureMeasurement = try XCTUnwrap(measurements.pendingMeasurements.first)

        // measurements are prepended
        guard case .bloodPressure = bloodPressureMeasurement else {
            XCTFail("Unexpected type of measurement: \(bloodPressureMeasurement)")
            return
        }

        measurements.discardMeasurement(bloodPressureMeasurement)
        XCTAssertTrue(measurements.shouldPresentMeasurements)
        XCTAssertEqual(measurements.pendingMeasurements.count, 1)

        let weightMeasurement = try XCTUnwrap(measurements.pendingMeasurements.first)
        guard case .weight = weightMeasurement else {
            XCTFail("Unexpected type of measurement: \(weightMeasurement)")
            return
        }
    }

    func testBluetoothMeasurementCodable() throws { // swiftlint:disable:this function_body_length
        let weightMeasurement =
            """
            {
                "type": "weight",
                "measurement": {"weight":8400, "unit":"si", "timeStamp":{"minutes":33,"day":5,"year":2024,"hours":12,"seconds":11,"month":6}},
                "features": 6
            }

            """
        let bloodPressureMeasurement =
            """
            {
                "type":"bloodPressure",
                "measurement":{
                    "unit":"mmHg",
                    "systolicValue":62470,
                    "diastolicValue":62080,
                    "timeStamp":{"seconds":11,"day":5,"hours":12,"year":2024,"month":6,"minutes":33},
                    "meanArterialPressure":62210,
                    "pulseRate":62060,
                    "measurementStatus":0,
                    "userId":1
                },
                "features":257
            }

            """

        let decoder = JSONDecoder()

        let weightData = try XCTUnwrap(weightMeasurement.data(using: .utf8))
        let pressureData = try XCTUnwrap(bloodPressureMeasurement.data(using: .utf8))

        let decodedWeight = try decoder.decode(BluetoothHealthMeasurement.self, from: weightData)
        let decodedPressure = try decoder.decode(BluetoothHealthMeasurement.self, from: pressureData)

        let dateTime = DateTime(year: 2024, month: .june, day: 5, hours: 12, minutes: 33, seconds: 11)
        XCTAssertEqual(
            decodedWeight,
            .weight(.init(weight: 8400, unit: .si, timeStamp: dateTime), [.bmiSupported, .multipleUsersSupported])
        )

        XCTAssertEqual(
            decodedPressure,
            .bloodPressure(
                .init(
                    systolic: 103,
                    diastolic: 64,
                    meanArterialPressure: 77,
                    unit: .mmHg,
                    timeStamp: dateTime,
                    pulseRate: 62,
                    userId: 1,
                    measurementStatus: []
                ),
                [.bodyMovementDetectionSupported, .userFacingTimeSupported]
            )
        )
    }
}
