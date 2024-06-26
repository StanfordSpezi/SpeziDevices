//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

@testable import SpeziDevices
import XCTest


class ImageReferenceTests: XCTestCase {
    func testAssetCodable() throws {
        for bundle in Bundle.allBundles {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let value = ImageReference.asset("ref", bundle: bundle)
            let referenceString = try encoder.encode(value)
            let reference = try decoder.decode(ImageReference.self, from: referenceString)

            XCTAssertEqual(reference, value, "Failed to encode/decode asset for bundle \(String(describing: bundle.bundleIdentifier))")
        }
    }

    func testSystemCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let value = ImageReference.system("sensor")
        let referenceString = try encoder.encode(value)
        let reference = try decoder.decode(ImageReference.self, from: referenceString)

        XCTAssertEqual(reference, value)
    }
}
