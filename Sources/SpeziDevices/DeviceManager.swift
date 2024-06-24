//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OrderedCollections
import Spezi
import SpeziBluetooth
import SpeziBluetoothServices
import SwiftUI


@Observable
public final class DeviceManager: Module, EnvironmentAccessible, DefaultInitializable { // TODO: "PairedDevices" rename?
    /// Determines if the device discovery sheet should be presented.
    @MainActor public var presentingDevicePairing = false // TODO: "should" naming
    @MainActor public private(set) var discoveredDevices: OrderedDictionary<UUID, any PairableDevice> = [:]
    @MainActor @ObservationIgnored private var _pairedDevices: [PairedDeviceInfo] = [] // TODO: @AppStorage("pairedDevices")

    @MainActor private(set) var peripherals: [UUID: any PairableDevice] = [:]

    @MainActor public var pairedDevices: [PairedDeviceInfo] {
        get {
            access(keyPath: \.pairedDevices)
            return _pairedDevices
        }
        set {
            withMutation(keyPath: \.pairedDevices) {
                _pairedDevices = newValue
            }
        }
    }


    @MainActor public var scanningNearbyDevices: Bool { // TODO: isScanningForNearby!
        pairedDevices.isEmpty || presentingDevicePairing
    }

    @Application(\.logger) @ObservationIgnored private var logger
    
    @Dependency @ObservationIgnored private var bluetooth: Bluetooth?


    private var stateSubscriptionTask: Task<Void, Never>? {
        willSet {
            stateSubscriptionTask?.cancel()
        }
    }


    public required init() {} // TODO: configure automatic search without devices paired!

    public func configure() {
        guard let bluetooth else {
            self.logger.warning("DeviceManager initialized without Bluetooth dependency!")
            return // useful for e.g. previews
        }

        // TODO: bit weird API wise!
            // We need to detach to not copy task local values
        Task.detached { @MainActor in
            // TODO: cancel all that if the last device is forgotten?
            self.stateSubscriptionTask = Task.detached { [weak self] in
                for await nextState in await bluetooth.stateSubscription {
                    print("Bluetooth Module state is now \(nextState)")
                    // TODO: asdasd, do something with that!
                    // TODO: actually do something with that!
                }
            }

            guard !self.pairedDevices.isEmpty else {
                return // no devices paired, no need to power up central
            }
            // TODO: we need to redo this once bluetooth powers on?
            // TODO: stateSubcription + powerOn() call!

            await bluetooth.powerOn() // TODO: should we do that on first connected device?
            if case .poweredOn = bluetooth.state {
                await self.handleCentralPoweredOn()
            }
        }
    }

    @MainActor
    public func isConnected(device: UUID) -> Bool {
        peripherals[device]?.state == .connected
    }

    @MainActor
    public func isPaired<Device: PairableDevice>(_ device: Device) -> Bool {
        pairedDevices.contains { $0.id == device.id } // TODO: more efficient lookup!
    }

    @MainActor
    public func handleDeviceStateUpdated<Device: PairableDevice>(_ device: Device, _ state: PeripheralState) {
        guard case .disconnected = state else {
            return
        }

        guard let deviceInfoIndex = pairedDevices.firstIndex(where: { $0.id == device.id }) else {
            return // not paired
        }

        // TODO: only update if previous state was connected (might have been just connecting!)
        pairedDevices[deviceInfoIndex].lastSeen = .now

        Task {
            // TODO: log?
            await device.connect() // TODO: handle something about that?, reuse with configure method?
        }
    }

    @MainActor
    public func nearbyPairableDevice<Device: PairableDevice>(_ device: Device) { // TODO: rename?
        guard discoveredDevices[device.id] == nil else {
            return
        }

        guard !isPaired(device) else {
            return
        }

        self.logger.info("Detected nearby \(Device.self) accessory.")
        // TODO: previously we logged the manufacturer data!

        discoveredDevices[device.id] = device
        presentingDevicePairing = true
    }


    @MainActor
    public func registerPairedDevice<Device: PairableDevice>(_ device: Device) async {
        var batteryLevel: UInt8?
        if let batteryDevice = device as? any BatteryPoweredDevice {
            batteryLevel = batteryDevice.battery.batteryLevel
        }

        if device.deviceInformation.modelNumber == nil && device.deviceInformation.$modelNumber.isPresent {
            // make sure it isn't just a race condition that we haven't received a value yet
            do {
                let readModel = try await device.deviceInformation.$modelNumber.read()
                self.logger.info("ModelNumber was not present on device \(device.label), was read as \"\(readModel)\".")
            } catch {
                logger.debug("Failed to retrieve model number for device \(Device.self): \(error)")
            }
        }

        let deviceInfo = PairedDeviceInfo(
            id: device.id,
            deviceType: Device.deviceTypeIdentifier,
            name: device.label,
            model: device.deviceInformation.modelNumber,
            icon: device.icon,
            batteryPercentage: batteryLevel
        )

        pairedDevices.append(deviceInfo)
        discoveredDevices[device.id] = nil


        assert(peripherals[device.id] == nil, "Cannot overwrite peripheral. Device \(deviceInfo) was paired twice.")
        // TODO: convert to persistent device!
        peripherals[device.id] = device

        self.logger.debug("Device \(device.label) with id \(device.id) is now paired!")
    }

    @MainActor
    public func handleDiscardedDevice<Device: PairableDevice>(_ device: Device) { // TODO: naming?
        // device discovery was cleared by SpeziBluetooth
        self.logger.debug("\(Device.self) \(device.label) was discarded from discovered devices.") // TODO: devices do not disappear currently???
        discoveredDevices[device.id] = nil
    }

    @MainActor
    public func forgetDevice(id: UUID) {
        pairedDevices.removeAll { info in
            info.id == id
        }

        let device = peripherals.removeValue(forKey: id)
        if let device {
            Task {
                await device.disconnect()
            }
        }
        // TODO: make sure to remove them from discoveredDevices? => should happen automatically?
    }

    @MainActor
    public func updateBattery<Device: PairableDevice>(for device: Device, percentage: UInt8) {
        guard let index = pairedDevices.firstIndex(where: { $0.id == device.id }) else {
            return
        }
        pairedDevices[index].lastBatteryPercentage = percentage
    }

    private func handleBluetoothStateChanged(_ state: BluetoothState) {

    }

    @MainActor
    private func handleCentralPoweredOn() async {
        guard let bluetooth else {
            return
        }

        // TODO: check powered on?

        // we just reuse the configured Bluetooth devices
        let configuredDevices = bluetooth.configuredPairableDevices

        for deviceInfo in self.pairedDevices {
            guard self.peripherals[deviceInfo.id] == nil else {
                continue
            }

            guard let deviceType = configuredDevices[deviceInfo.deviceType] else {
                self.logger.error("Unsupported device type \"\(deviceInfo.deviceType)\" for paired device \(deviceInfo.name).")
                continue
            }

            let device = await deviceType.retrieveDevice(from: bluetooth, with: deviceInfo.id)

            guard let device else {
                // TODO: once spezi bluetooth works (waiting for connected), this is an indication that the device was unpaired???? => we know it is powered on!
                self.logger.warning("Device \(deviceInfo.id) \(deviceInfo.name) could not be retrieved!")
                continue
            }

            assert(self.peripherals[device.id] == nil, "Cannot overwrite peripheral. Device \(deviceInfo) was paired twice.")
            self.peripherals[device.id] = device

            // TODO: make task group!
            // TODO: create tasks and store them?
            await device.connect() // TODO: might want to cancel that?

            // TODO: call connect after device disconnects?
        }
    }

    deinit {
        _peripherals.removeAll() // TODO: clear any other state?
    }
}


extension Bluetooth {
    fileprivate nonisolated var configuredPairableDevices: [String: any PairableDevice.Type] {
        configuration.reduce(into: [:]) { partialResult, descriptor in
            guard let pairableDevice = descriptor.deviceType as? any PairableDevice.Type else {
                return
            }
            partialResult[pairableDevice.deviceTypeIdentifier] = pairableDevice
        }
    }
}


extension PairableDevice {
    fileprivate static func retrieveDevice(from bluetooth: Bluetooth, with id: UUID) async -> Self? {
        await bluetooth.retrieveDevice(for: id)
    }
}
