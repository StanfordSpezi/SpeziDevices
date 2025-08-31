//
// This source file is part of the Stanford SpeziDevices open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport) import SpeziBluetooth
import SpeziBluetoothServices
@_spi(TestingSupport) @testable import SpeziDevices
import SpeziFoundation
import SpeziTesting
import Testing

@Suite
struct PairedDevicesTests {
    @MainActor
    @Test
    func testPairDevice() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()


        // ensure PairedDevices gets injected into the MockDevice
        withDependencyResolution {
            device
            devices
        }

        device.isInPairingMode = true


        #expect(!devices.isConnected(device: device.id))
        #expect(!devices.isPaired(device))

        devices.configure(device: device, accessing: device.$state, device.$advertisementData, device.$nearby)

        try await devices.pair(with: device)


        #expect(devices.isPaired(device))
        #expect(devices.isConnected(device: device.id))

        #expect(devices.pairedDevices?.count == 1)
        let deviceInfo = try #require(devices.pairedDevices?.first)

        #expect(deviceInfo.id == device.id)
        #expect(deviceInfo.deviceType == MockDevice.deviceTypeIdentifier)
        #expect(deviceInfo.icon == nil)
        #expect(deviceInfo.model == device.deviceInformation.modelNumber)
        #expect(deviceInfo.name == device.name)
        #expect(deviceInfo.lastBatteryPercentage == 85)

        let initialLastSeen = deviceInfo.lastSeen

        device.battery.$batteryLevel.inject(71)
        await device.disconnect()
        device.$nearby.inject(false)

        #expect(device.state == .disconnected)

        try await Task.sleep(for: .milliseconds(50))


        #expect(deviceInfo.lastSeen > initialLastSeen) // should be later and updated on disconnect
        #expect(deviceInfo.lastBatteryPercentage == 71) // should have captured the updated battery


        devices.updateName(for: deviceInfo, name: "Custom Name")
        #expect(deviceInfo.name == "Custom Name")

        let recentLastSeen = deviceInfo.lastSeen

        // test storage persistence!
        try devices.refreshPairedDevices()
        try {
            #expect(devices.pairedDevices?.count == 1)
            let info0 = try #require(devices.pairedDevices?.first)
            #expect(info0.name == "Custom Name")
            #expect(info0.lastBatteryPercentage == 71)
            #expect(info0.lastSeen == recentLastSeen)
        }()


        try await device.connect()
        try await Task.sleep(for: .seconds(1.1))
        #expect(device.state == .connected)


        devices.forgetDevice(id: device.id)
        try await Task.sleep(for: .milliseconds(50))
        
        #expect(device.state == .disconnected)
        #expect(devices.pairedDevices?.isEmpty == true)
        #expect(devices.discoveredDevices.isEmpty)
    }

    @MainActor
    @Test
    func testPairingErrors() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()

        withDependencyResolution {
            devices
        }

        device.isInPairingMode = true

        device.$nearby.inject(false)
        let error = await #expect(throws: DevicePairingError.self) { try await devices.pair(with: device) }
        #expect(error == .invalidState)
        device.$nearby.inject(true)

        try await device.connect()
        let error1 = await #expect(throws: DevicePairingError.self) { try await devices.pair(with: device) }
        #expect(error1 == .invalidState)
        await device.disconnect()

        device.isInPairingMode = false
        let error2 = await #expect(throws: DevicePairingError.self) { try await devices.pair(with: device) }
        #expect(error2 == .notInPairingMode)
        device.isInPairingMode = true

        await #expect(throws: TimeoutError.self) { try await devices.pair(with: device, timeout: .milliseconds(200)) }
    }
    
    @MainActor
    @Test
    func testPairingCancellation() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()

        withDependencyResolution {
            devices
        }

        device.isInPairingMode = true

        let task = Task {
            try await devices.pair(with: device)
        }

        try await Task.sleep(for: .milliseconds(50))
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }

        #expect(device.state == .disconnected)
    }

    @MainActor
    @Test
    func testFailedPairing() async throws {
        let device = MockDevice.createMockDevice()
        let devices = PairedDevices()

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

        let error = await #expect(throws: DevicePairingError.self) { try await task.value }
        #expect(error == .deviceDisconnected)

        #expect(device.state == .disconnected)
    }
}
