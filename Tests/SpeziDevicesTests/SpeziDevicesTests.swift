//
// This source file is part of the ENGAGE-HF project based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetoothServices
@_spi(TestingSupport) import SpeziDevices
import XCTest


final class SpeziDevicesTests: XCTestCase {
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
