//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import SpeziBluetooth
import SpeziBluetoothServices
@_spi(TestingSupport)
@testable import SpeziDevices
import SpeziFoundation
import SpeziTesting
import XCTest
import XCTestExtensions


final class PairedDevicesTests: XCTestCase {
    @MainActor
    func testPairDevice() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()


        // ensure PairedDevices gets injected into the MockDevice
        withDependencyResolution {
            device
            devices
        }

        async let _ = devices.run() // make sure lifecycle runs

        device.isInPairingMode = true


        XCTAssertFalse(devices.isConnected(device: device.id))
        XCTAssertFalse(devices.isPaired(device))

        devices.configure(device: device, accessing: device.$state, device.$advertisementData, device.$nearby)

        try await Task.sleep(for: .milliseconds(50))

        try await devices.pair(with: device)


        XCTAssertTrue(devices.isPaired(device))
        XCTAssertTrue(devices.isConnected(device: device.id))

        XCTAssertEqual(devices.pairedDevices?.count, 1)
        let deviceInfo = try XCTUnwrap(devices.pairedDevices?.first)

        XCTAssertEqual(deviceInfo.id, device.id)
        XCTAssertEqual(deviceInfo.deviceType, MockDevice.deviceTypeIdentifier)
        XCTAssertEqual(deviceInfo.icon, .system("sensor"))
        XCTAssertEqual(deviceInfo.model, device.deviceInformation.modelNumber)
        XCTAssertEqual(deviceInfo.name, "My Mock Device") // ensure this uses the appearance name
        XCTAssertEqual(deviceInfo.lastBatteryPercentage, 85)

        let initialLastSeen = deviceInfo.lastSeen

        device.battery.$batteryLevel.inject(71)
        await device.disconnect()
        device.$nearby.inject(false)

        XCTAssertEqual(device.state, .disconnected)

        try await Task.sleep(for: .milliseconds(50))


        XCTAssertTrue(deviceInfo.lastSeen > initialLastSeen) // should be later and updated on disconnect
        XCTAssertEqual(deviceInfo.lastBatteryPercentage, 71) // should have captured the updated battery


        devices.updateName(for: deviceInfo, name: "Custom Name")
        XCTAssertEqual(deviceInfo.name, "Custom Name")

        let recentLastSeen = deviceInfo.lastSeen

        // test storage persistence!
        try devices.refreshPairedDevices()
        try {
            XCTAssertEqual(devices.pairedDevices?.count, 1)
            let info0 = try XCTUnwrap(devices.pairedDevices?.first)
            XCTAssertEqual(info0.name, "Custom Name")
            XCTAssertEqual(info0.lastBatteryPercentage, 71)
            XCTAssertEqual(info0.lastSeen, recentLastSeen)
        }()


        try await device.connect()
        try await Task.sleep(for: .seconds(1.1))
        XCTAssertEqual(device.state, .connected)


        try await devices.forgetDevice(id: device.id)
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(device.state, .disconnected)
        XCTAssertEqual(devices.pairedDevices?.isEmpty, true)
        XCTAssertTrue(devices.discoveredDevices.isEmpty)
    }

    @MainActor
    func testPairingErrors() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()

        withDependencyResolution {
            devices
        }

        device.isInPairingMode = true
        devices.configure(device: device, accessing: device.$state, device.$advertisementData, device.$nearby)

        device.$nearby.inject(false)
        try await XCTAssertThrowsErrorAsync(await devices.pair(with: device)) { error in
            XCTAssertEqual(try XCTUnwrap(error as? DevicePairingError), .invalidState)
        }
        device.$nearby.inject(true)

        try await device.connect()
        try await XCTAssertThrowsErrorAsync(await devices.pair(with: device)) { error in
            XCTAssertEqual(try XCTUnwrap(error as? DevicePairingError), .invalidState)
        }
        await device.disconnect()

        device.isInPairingMode = false
        try await XCTAssertThrowsErrorAsync(await devices.pair(with: device)) { error in
            XCTAssertEqual(try XCTUnwrap(error as? DevicePairingError), .notInPairingMode)
        }
        device.isInPairingMode = true
        device.$advertisementData.inject(.init())

        try await Task.sleep(for: .milliseconds(200))

        try await XCTAssertThrowsErrorAsync(await devices.pair(with: device, timeout: .milliseconds(200))) { error in
            XCTAssertTrue(error is TimeoutError, "Unexpected error \(error)")
        }
    }

    @MainActor
    func testPairingCancellation() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()

        withDependencyResolution {
            devices
        }

        device.isInPairingMode = true
        devices.configure(device: device, accessing: device.$state, device.$advertisementData, device.$nearby)

        try await Task.sleep(for: .milliseconds(50))

        let task = Task {
            try await devices.pair(with: device)
        }

        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        try await XCTAssertThrowsErrorAsync(await task.value) { error in
            XCTAssertTrue(error is CancellationError, "Unexpected error: \(error)")
        }

        XCTAssertEqual(device.state, .disconnected)
    }

    @MainActor
    func testFailedPairing() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()

        withDependencyResolution {
            device
            devices
        }

        device.isInPairingMode = true

        devices.configure(device: device, accessing: device.$state, device.$advertisementData, device.$nearby)

        try await Task.sleep(for: .milliseconds(50))

        let task = Task {
            try await devices.pair(with: device)
        }

        try await Task.sleep(for: .milliseconds(1150))
        await device.disconnect()

        try await XCTAssertThrowsErrorAsync(await task.value) { error in
            XCTAssertEqual(try XCTUnwrap(error as? DevicePairingError), .deviceDisconnected)
        }

        XCTAssertEqual(device.state, .disconnected)
    }
}
