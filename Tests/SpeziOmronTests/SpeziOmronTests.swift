//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport) import ByteCoding
import CoreBluetooth
@_spi(TestingSupport) import SpeziBluetooth
import SpeziBluetoothServices
@_spi(TestingSupport) import SpeziDevices
@testable import SpeziOmron
import XCTByteCoding
import XCTest
import XCTestExtensions


typealias RACP = RecordAccessControlPoint<OmronRecordAccessOperand>

final class SpeziOmronTests: XCTestCase {
    func testModelCodable() throws {
        let string = "\"SC-150\""
        let data = try XCTUnwrap(string.data(using: .utf8))
        let decoded = try JSONDecoder().decode(OmronModel.self, from: data)
        XCTAssertEqual(decoded, .sc150)
    }

    func testOmronManufacturerData() throws {
        try testIdentity(from: OmronManufacturerData(
            timeSet: true,
            pairingMode: .pairingMode,
            streamingMode: .dataCommunication,
            servicesMode: .bluetoothStandard,
            users: [.init(id: 1, sequenceNumber: 3, recordsNumber: 8)]
        ))

        try testIdentity(from: OmronManufacturerData(
            timeSet: false,
            pairingMode: .transferMode,
            streamingMode: .streaming,
            servicesMode: .omronExtension,
            users: [
                .init(id: 1, sequenceNumber: 3, recordsNumber: 8),
                .init(id: 2, sequenceNumber: 0, recordsNumber: 0)
            ]
        ))

        try testIdentity(from: OmronManufacturerData(
            timeSet: false,
            pairingMode: .transferMode,
            streamingMode: .streaming,
            servicesMode: .omronExtension,
            users: [
                .init(id: 1, sequenceNumber: 3, recordsNumber: 8),
                .init(id: 2, sequenceNumber: 0, recordsNumber: 0),
                .init(id: 3, sequenceNumber: 5, recordsNumber: 0)
            ]
        ))

        try testIdentity(from: OmronManufacturerData(
            timeSet: false,
            pairingMode: .transferMode,
            streamingMode: .streaming,
            servicesMode: .omronExtension,
            users: [
                .init(id: 1, sequenceNumber: 3, recordsNumber: 8),
                .init(id: 2, sequenceNumber: 0, recordsNumber: 0),
                .init(id: 3, sequenceNumber: 5, recordsNumber: 0),
                .init(id: 4, sequenceNumber: 9, recordsNumber: 0)
            ]
        ))
    }

    func testOmronHealthDevice() throws {
        let manufacturerData = OmronManufacturerData(pairingMode: .pairingMode, users: [.init(id: 1, sequenceNumber: 3, recordsNumber: 8)])

        let device = MockDevice.createMockDevice()
        device.$advertisementData.inject(AdvertisementData([
            CBAdvertisementDataManufacturerDataKey: manufacturerData.encode()
        ]))

        XCTAssertEqual(device.manufacturerData?.pairingMode, .pairingMode)

        let manufacturerData0 = OmronManufacturerData(pairingMode: .transferMode, users: [.init(id: 1, sequenceNumber: 3, recordsNumber: 8)])
        device.$advertisementData.inject(AdvertisementData([
            CBAdvertisementDataManufacturerDataKey: manufacturerData0.encode()
        ]))

        XCTAssertEqual(device.manufacturerData?.pairingMode, .transferMode)


        device.deviceInformation.$modelNumber.inject(OmronModel.bp5250.rawValue)

        XCTAssertEqual(device.model, .bp5250)
    }

    func testRACPReportStoredRecords() throws {
        try testIdentity(from: RACP.reportStoredRecords(.allRecords))
        try testIdentity(from: RACP.reportStoredRecords(.lastRecord))
        try testIdentity(from: RACP.reportStoredRecords(.firstRecord))
        try testIdentity(from: RACP.reportStoredRecords(.greaterThanOrEqualTo(sequenceNumber: 12)))

        try testIdentity(of: RACP.self, from: XCTUnwrap(Data(hex: "0x0101"))) // Report All Records
        try testIdentity(of: RACP.self, from: XCTUnwrap(Data(hex: "0x010304FFFF"))) // Report greater than or equal to
        try testIdentity(of: RACP.self, from: XCTUnwrap(Data(hex: "0x06000101"))) // SUCCESS
        try testIdentity(of: RACP.self, from: XCTUnwrap(Data(hex: "0x06000106"))) // no records found
    }

    func testRACPReportNumberOfStoredRecords() throws {
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.allRecords))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.lastRecord))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.firstRecord))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.greaterThanOrEqualTo(sequenceNumber: 12)))

        try testIdentity(of: RACP.self, from: XCTUnwrap(Data(hex: "0x0401"))) // Report All Records
        try testIdentity(of: RACP.self, from: XCTUnwrap(Data(hex: "0x040304FFFF"))) // Report greater than or equal to
        try testIdentity(of: RACP.self, from: XCTUnwrap(Data(hex: "0x0500FFFF"))) // Response
    }

    func testRACPNumberOfLatestRecords() throws {
        try testIdentity(from: RACP.reportSequenceNumberOfLatestRecords())

        try testIdentity(of: RACP.self, from: XCTUnwrap(Data(hex: "0x1100FFFF"))) // Response
    }

    func testRACPReportRecordsRequest() async throws {
        let service = OmronOptionService()

        service.$recordAccessControlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .reportStoredRecords, response: .success)))
        }
        try await service.reportStoredRecords(.allRecords)

        service.$recordAccessControlPoint.onRequest { _ in
            RACP(
                opCode: .responseCode,
                operator: .null,
                operand: .generalResponse(.init(requestOpCode: .reportStoredRecords, response: .noRecordsFound))
            )
        }
        try await XCTAssertThrowsErrorAsync(await service.reportStoredRecords(.allRecords)) { error in
            try XCTAssertEqual(XCTUnwrap(error as? RecordAccessResponseCode), .noRecordsFound)
        }
    }

    func testRACPReportNumberOfStoredRecordsRequest() async throws {
        let service = OmronOptionService()

        service.$recordAccessControlPoint.onRequest { _ in
            RACP(opCode: .numberOfStoredRecordsResponse, operator: .null, operand: .numberOfRecords(1234))
        }

        let count = try await service.reportNumberOfStoredRecords(.allRecords)
        XCTAssertEqual(count, 1234)

        service.$recordAccessControlPoint.onRequest { _ in
            RACP(opCode: .numberOfStoredRecordsResponse, operator: .null, operand: .sequenceNumber(1234))
        }
        try await XCTAssertThrowsErrorAsync(await service.reportNumberOfStoredRecords(.allRecords)) { error in
            try XCTAssertEqual(XCTUnwrap(error as? RecordAccessResponseFormatError).reason, .unexpectedOperand)
        }
    }

    func testRACPReportSequenceNumberOfLatestRecords() async throws {
        let service = OmronOptionService()

        service.$recordAccessControlPoint.onRequest { _ in
            RACP(opCode: .omronSequenceNumberOfLatestRecordsResponse, operator: .null, operand: .sequenceNumber(1234))
        }

        let count = try await service.reportSequenceNumberOfLatestRecords()
        XCTAssertEqual(count, 1234)

        service.$recordAccessControlPoint.onRequest { _ in
            RACP(opCode: .omronSequenceNumberOfLatestRecordsResponse, operator: .null, operand: .numberOfRecords(1234))
        }
        try await XCTAssertThrowsErrorAsync(await service.reportSequenceNumberOfLatestRecords()) { error in
            try XCTAssertEqual(XCTUnwrap(error as? RecordAccessResponseFormatError).reason, .unexpectedOperand)
        }
    }
}


#if compiler(>=6)
#warning("Use @retroactive annotation instead if spelling out module names once we drop support for <6 toolchains.")
#endif
extension SpeziDevices.MockDevice: SpeziOmron.OmronHealthDevice {}
