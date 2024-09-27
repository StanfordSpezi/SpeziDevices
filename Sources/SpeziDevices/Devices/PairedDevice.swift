//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OSLog
import SpeziBluetooth
import SpeziFoundation


@MainActor
@Observable
final class PairedDevice: Sendable {
    private static nonisolated let logger = Logger(subsystem: "edu.stanford.spezi.SpeziDevices", category: "PairedDevice")

    let info: PairedDeviceInfo

    private(set) var peripheral: (any PairableDevice)?

    private var connectionAttemptCount: UInt = 0
    @ObservationIgnored private(set) var connectionAttemptTask: Task<Void, Never>? {
        willSet {
            connectionAttemptTask?.cancel()
        }
    }

    @ObservationIgnored private(set) var willBeRemoved = false
    private let retrieveAccess = AsyncSemaphore()

    init(info: PairedDeviceInfo, assigning peripheral: (any PairableDevice)? = nil) {
        self.info = info
        self.peripheral = peripheral
    }

    func markForRemoval(_ willBeRemoved: Bool = true) {
        self.willBeRemoved = willBeRemoved
    }

    func removeDevice(manualDisconnect: Bool) async {
        self.markForRemoval()

        let peripheral = self.peripheral
        await handlePowerOff()

        if let peripheral, manualDisconnect {
            await peripheral.disconnect()
        }
    }

    func handlePowerOff() async {
        let connectionAttemptTask = cancelConnectionAttemptReturningPrevious()
        self.peripheral = nil
        if let connectionAttemptTask {
            await connectionAttemptTask.value // TODO: are we sure the connect action is fully cancellable?

            // TODO: remove?
            Self.logger.debug("Successfully cancelled connection attempt \(self.connectionAttemptCount) for device \(self.info.name), \(self.info.id)")
        }
    }

    func updateUponConfiguration<Device: PairableDevice>(of device: Device) {
        info.peripheralName = device.name
        info.icon = Device.appearance.deviceIcon(variantId: info.variantIdentifier) // the asset might have changed
    }

    func retrieveDevice(for deviceType: any PairableDevice.Type, using bluetooth: borrowing Bluetooth) async {
        defer {
            retrieveAccess.signal()
        }

        try? await retrieveAccess.waitCheckingCancellation()
        guard !Task.isCancelled else {
            return
        }

        if let peripheral {
            Self.logger.debug("Ignoring request to retrieve device. Device \(peripheral.label), \(peripheral.id) already associated.")
            return
        }

        let info = info

        Self.logger.debug("Retrieving device for \(info.name), \(info.id)")
        let device = await deviceType.retrieveDevice(from: bluetooth, with: info.id)

        guard let device else {
            info.notLocatable = true
            Self.logger.warning("Device \(info.id) \(info.name) could not be retrieved!")
            return
        }

        assert(peripheral == nil, "Cannot overwrite peripheral. Device \(info) was paired twice.")
        self.peripheral = device

        connectionAttempt()
    }

    func handleDeviceStateUpdated<Device: PairableDevice>(for device: Device, old oldState: PeripheralState, new newState: PeripheralState) {
        guard device === peripheral else {
            Self.logger.error("Received state update for unexpected device instance: \(device.id) vs. \(self.peripheral.map { $0.id.description } ?? "nil")")
            return
        }

        switch newState {
        case .connected:
            updateLastSeen(for: device)
        case .disconnecting:
            if case .connected = oldState {
                updateLastSeen(for: device)
            }
        case .disconnected:
            if case .connected = oldState {
                updateLastSeen(for: device)
            }

            // TODO: this flag might not be set if the device is unpaired from settings!
            if !willBeRemoved { // long-running reconnect (if applicable)
                Self.logger.debug("Restoring connection attempt for device \(device.label), \(device.id) after disconnect.")
                connectionAttempt()
            }

        default:
            break
        }
    }

    func updateBattery<Device: PairableDevice>(for device: Device, percentage: UInt8) {
        guard device === peripheral else {
            Self.logger.error("Received battery update for unexpected device instance: \(device.id) vs. \(self.peripheral.map { $0.id.description } ?? "nil")")
            return
        }

        Self.logger.debug("Updated battery level for \(device.label): \(percentage) %")
        info.lastBatteryPercentage = percentage
    }

    private func updateLastSeen<Device: PairableDevice>(for device: Device, lastSeen: Date = .now) {
        Self.logger.debug("Updated lastSeen for \(device.label): \(lastSeen) %")
        info.lastSeen = lastSeen
        if let model = device.deviceInformation.modelNumber {
            info.model = model
        }
        if let batteryPowered = device as? BatteryPoweredDevice,
           let battery = batteryPowered.battery.batteryLevel {
            info.lastBatteryPercentage = battery
        }
    }

    deinit {
        connectionAttemptTask?.cancel()
    }
}

// MARK: - Connection Attempt

extension PairedDevice {
    private func connectionAttempt() {
        let previousTask = cancelConnectionAttemptReturningPrevious()

        guard peripheral != nil, !willBeRemoved else {
            return
        }

        connectionAttemptCount &+= 1

        let taskAttempt = connectionAttemptCount
        connectionAttemptTask = Task { @MainActor [weak self] in
            await previousTask?.value // make sure its ordered

            var backOff: Duration = .milliseconds(500) // exponential back-off for retry!

            var iteration: UInt = 0
            while !Task.isCancelled {
                guard let device = self?.peripheral else {
                    return // device or self got deallocated
                }

                let attempt = "\(taskAttempt).\(iteration)"

                do {
                    Self.logger.debug("Connection attempt \(attempt) connects to device \(device.label), \(device.id) ...")
                    try await device.connect()
                    Self.logger.debug("Connection attempt \(attempt) to device \(device.label), \(device.id) completed successfully.")
                    break // connection attempt was successful
                } catch let BluetoothError.invalidState(state) {
                    Self.logger.warning("Failed connection attempt \(attempt) as bluetooth was not in poweredOn state (actual: \(state)). Aborting.")
                    return
                } catch {
                    if Task.isCancelled || error is CancellationError {
                        Self.logger.debug("Connection attempt \(attempt) for device \(device.label), \(device.id) was cancelled.")
                        return
                    }
                    Self.logger.warning("Failed connection attempt \(attempt) for device \(device.label) (Retrying in \(backOff)): \(error)")
                    try? await Task.sleep(for: backOff)
                    backOff *= 2

                    // TODO: if the error is a permission error, abort, device was removed by accessory setup kit or user rejected permissions!
                    //      : Failed to connect to 'EVOLV'@3E1851C3-5CE3-B407-5A3C-7A7B04FDAFB4: Error Domain=CBInternalErrorDomain Code=10
                    //   => "Operation is not allowed" UserInfo={NSLocalizedDescription=Operation is not allowed}
                }

                iteration &+= 1
            }
        }
    }

    @discardableResult
    private func cancelConnectionAttemptReturningPrevious() -> Task<Void, Never>? {
        guard let connectionAttemptTask else {
            return nil
        }
        if !connectionAttemptTask.isCancelled {
            Self.logger.debug("Cancelling connection attempt \(self.connectionAttemptCount) for device \(self.info.name), \(self.info.id)")
        }
        connectionAttemptTask.cancel()
        return connectionAttemptTask
    }
}


extension PairableDevice {
    fileprivate static func retrieveDevice(from bluetooth: Bluetooth, with id: UUID) async -> Self? {
        await bluetooth.retrieveDevice(for: id, as: Self.self)
    }
}
