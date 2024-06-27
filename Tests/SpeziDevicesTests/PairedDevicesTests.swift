//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport) import SpeziBluetooth
import SpeziBluetoothServices
@_spi(TestingSupport) import SpeziDevices
import SpeziFoundation
import XCTest
import XCTestExtensions
import XCTSpezi


final class PairedDevicesTests: XCTestCase {
    @MainActor
    func testPairDevice() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()
        defer {
            devices.clearStorage()
        }


        // ensure PairedDevices gets injected into the MockDevice
        withDependencyResolution {
            device
            devices
        }

        device.isInPairingMode = true


        XCTAssertFalse(devices.isConnected(device: device.id))
        XCTAssertFalse(devices.isPaired(device))

        devices.configure(device: device, accessing: device.$state, device.$advertisementData, device.$nearby)

        try await devices.pair(with: device)


        XCTAssertTrue(devices.isPaired(device))
        XCTAssertTrue(devices.isConnected(device: device.id))

        XCTAssertEqual(devices.pairedDevices.count, 1)
        let deviceInfo = try XCTUnwrap(devices.pairedDevices.first)

        XCTAssertEqual(deviceInfo.id, device.id)
        XCTAssertEqual(deviceInfo.deviceType, MockDevice.deviceTypeIdentifier)
        XCTAssertNil(deviceInfo.icon)
        XCTAssertEqual(deviceInfo.model, device.deviceInformation.modelNumber)
        XCTAssertEqual(deviceInfo.name, device.name)
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
        try { // test storage persistence!
            let devices2 = PairedDevices()
            XCTAssertEqual(devices2.pairedDevices.count, 1)
            let info0 = try XCTUnwrap(devices2.pairedDevices.first)
            XCTAssertEqual(info0.name, "Custom Name")
            XCTAssertEqual(info0.lastBatteryPercentage, 71)
            XCTAssertEqual(info0.lastSeen, recentLastSeen)
        }()


        await device.connect()
        try await Task.sleep(for: .seconds(1.1))
        XCTAssertEqual(device.state, .connected)


        devices.forgetDevice(id: device.id)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(device.state, .disconnected)
        XCTAssertTrue(devices.pairedDevices.isEmpty)
        XCTAssertTrue(devices.discoveredDevices.isEmpty)
    }

    @MainActor
    func testPairingErrors() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()
        defer {
            devices.clearStorage()
        }

        withDependencyResolution {
            devices
        }

        device.isInPairingMode = true

        device.$nearby.inject(false)
        try await XCTAssertThrowsErrorAsync(await devices.pair(with: device)) { error in
            XCTAssertEqual(try XCTUnwrap(error as? DevicePairingError), .invalidState)
        }
        device.$nearby.inject(true)

        await device.connect()
        try await XCTAssertThrowsErrorAsync(await devices.pair(with: device)) { error in
            XCTAssertEqual(try XCTUnwrap(error as? DevicePairingError), .invalidState)
        }
        await device.disconnect()

        device.isInPairingMode = false
        try await XCTAssertThrowsErrorAsync(await devices.pair(with: device)) { error in
            XCTAssertEqual(try XCTUnwrap(error as? DevicePairingError), .notInPairingMode)
        }
        device.isInPairingMode = true

        try await XCTAssertThrowsErrorAsync(await devices.pair(with: device, timeout: .milliseconds(200))) { error in
            XCTAssertTrue(error is TimeoutError)
        }
    }

    @MainActor
    func testPairingCancellation() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()
        defer {
            devices.clearStorage()
        }

        withDependencyResolution {
            devices
        }

        device.isInPairingMode = true

        let task = Task {
            try await devices.pair(with: device)
        }

        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        try await XCTAssertThrowsErrorAsync(await task.value) { error in
            XCTAssertTrue(error is CancellationError)
        }

        XCTAssertEqual(device.state, .disconnected)
    }

    @MainActor
    func testFailedPairing() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()
        defer {
            devices.clearStorage()
        }

        withDependencyResolution {
            device
            devices
        }

        device.isInPairingMode = true

        devices.configure(device: device, accessing: device.$state, device.$advertisementData, device.$nearby)

        let task = Task {
            try await devices.pair(with: device)
        }

        try await Task.sleep(for: .milliseconds(1150))
        await device.disconnect()

        try await XCTAssertThrowsErrorAsync(await task.value) { error in
            print(error)
            XCTAssertEqual(try XCTUnwrap(error as? DevicePairingError), .deviceDisconnected)
        }

        XCTAssertEqual(device.state, .disconnected)
    }
}
