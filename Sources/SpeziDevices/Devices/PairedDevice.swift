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

struct DeviceConnections: Sendable { // TODO: move!
    private static let logger = Logger(subsystem: "edu.stanford.spezi.spezidevices", category: "\(Self.self)")
    private enum Input {
        case connect(_ device: PairedDevice, _ bluetooth: Bluetooth)
        case cancel(_ device: PairedDevice)
        case clearStaleState(deviceId: UUID, id: UUID)
    }

    private let input: (stream: AsyncStream<Input>, continuation: AsyncStream<Input>.Continuation)
    private let retry: RetryConfiguration

    init(retry: RetryConfiguration = RetryConfiguration()) {
        self.input = AsyncStream.makeStream()
        self.retry = retry
    }

    func connect(device: PairedDevice, using bluetooth: Bluetooth) {
        input.continuation.yield(.connect(device, bluetooth))
    }

    func cancel(device: PairedDevice) {
        input.continuation.yield(.cancel(device))
    }

    func run() async {
        await withDiscardingTaskGroup { group in
            var state: [UUID: (handle: CancelableTaskHandle, id: UUID)] = [:]

            for await input in self.input.stream {
                switch input {
                case let .connect(device, bluetooth):
                    guard state[device.id] == nil else {
                        Self.logger.warning("Ignoring connect request as task is still running.")
                        continue
                    }

                    let id = UUID()

                    let handle = group.addCancelableTask {
                        await device.run(using: bluetooth, retry: self.retry)
                        self.input.continuation.yield(.clearStaleState(deviceId: device.id, id: id))
                    }

                    state[device.id] = (handle, id)
                case let .cancel(device ):
                    let entry = state.removeValue(forKey: device.id)
                    entry?.handle.cancel()
                case let .clearStaleState(deviceId, id):
                    guard let entry = state[deviceId],
                          entry.id == id else {
                        continue
                    }
                    entry.handle.cancel()
                    state.removeValue(forKey: deviceId)
                }
            }
        }
    }
}


struct RetryConfiguration {
    var initialBackoff: Duration
    var maxBackoff: Duration
    var minimumQuietPeriod: Duration

    init(
        initialBackoff: Duration = .seconds(0.5),
        maxBackoff: Duration = .seconds(30),
        minimumQuietPeriod: Duration = .seconds(60)
    ) {
        self.initialBackoff = initialBackoff
        self.maxBackoff = maxBackoff
        self.minimumQuietPeriod = minimumQuietPeriod
    }
}


@MainActor // TODO: is this really needed to be main actor?
@Observable // TODO: why is this observable?
final class PairedDevice: Sendable {
    private enum ConnectionEvent {
        case disconnected
        case removed(disconnect: Bool)
    }

    private enum ConnectResult {
        case connected
        case end
        case retry
    }

    private enum DisconnectListenerResult {
        case disconnected
        case finished
    }

    private static nonisolated let logger = Logger(subsystem: "edu.stanford.spezi.SpeziDevices", category: "PairedDevice")

    nonisolated let id: UUID
    @MainActor let info: PairedDeviceInfo

    private(set) var peripheral: (any PairableDevice)?
    private var events: (stream: AsyncStream<ConnectionEvent>, continuation: AsyncStream<ConnectionEvent>.Continuation)

    init(info: PairedDeviceInfo, assigning peripheral: (any PairableDevice)? = nil) {
        self.events = AsyncStream.makeStream()
        self.id = info.id
        self.info = info
        self.peripheral = peripheral
    }

    func removeDevice(manualDisconnect: Bool, cancelling connections: DeviceConnections) {
        self.peripheral = nil

        // Do not call disconnect with AccessorySetupKit. We do not have the permission for that anymore.
        // The device will be disconnected automatically.
        events.continuation.yield(.removed(disconnect: manualDisconnect))
        
        connections.cancel(device: self)
    }

    func updateUponConfiguration<Device: PairableDevice>(of device: Device) {
        info.peripheralName = device.name
        info.icon = Device.appearance.deviceIcon(variantId: info.variantIdentifier) // the asset might have changed
    }

    @MainActor
    public func run(using bluetooth: Bluetooth, retry: RetryConfiguration) async {
        let peripheral: any PairableDevice

        if let existingPeripheral = self.peripheral {
            peripheral = existingPeripheral
        } else {
            let info = info
            guard let deviceType = bluetooth.pairableDevice(deviceTypeIdentifier: info.deviceType) else {
                Self.logger.error("Unsupported device type \"\(info.deviceType)\" for paired device \(info.name).")
                info.notLocatable = true
                return
            }

            if Task.isCancelled {
                return // already cancelled, do not even attempt to connect
            }

            guard let retrievedDevice = await self.retrieveDevice(for: deviceType, using: bluetooth) else {
                Self.logger.error("Failed to retrieve device from central \(info.deviceType) with name \(info.name).")
                info.notLocatable = true // TODO: is this decision final, any need to retry (not currently!)
                return
            }

            peripheral = retrievedDevice
        }

        if Task.isCancelled {
            return // already cancelled, do not even attempt to connect
        }

        var retryFactor: UInt = 1
        var lastError: ContinuousClock.Instant = .now

        connectLoop: while true {
            let result = await runConnectionAttempt(for: peripheral)

            switch result {
            case .end:
                break connectLoop
            case .connected:
                let disconnectResult = await waitForDisconnected(for: peripheral)

                switch disconnectResult {
                case .disconnected:
                    Self.logger.debug("Restoring connection attempt for device \(peripheral.label), \(peripheral.id) after disconnect.")
                    do {
                        try await Task.sleep(for: .seconds(2)) // TODO: configurable?
                    } catch {
                        break connectLoop // cancellation error
                    }
                case .finished:
                    break connectLoop // likely task got cancelled
                }
            case .retry:
                if (.now - lastError) >= retry.minimumQuietPeriod {
                    // if the last error is long enough ago, we reset our error counter
                    retryFactor = 1
                }

                lastError = .now

                let backoff = min(retry.initialBackoff * retryFactor, retry.maxBackoff)
                retryFactor <<= 1

                if backoff == retry.maxBackoff { // overflow protection
                    retryFactor >>= 1
                }

                Self.logger.debug("\(backoff) connection backoff for device \(peripheral.label), \(peripheral.id).")
                do {
                    try await Task.sleep(for: backoff)
                } catch {
                    break connectLoop // cancellation error
                }
            }
        }
    }

    private func waitForDisconnected(for peripheral: any PairableDevice) async -> DisconnectListenerResult {
        events.continuation.finish()
        events = AsyncStream.makeStream()

        eventLoop: for await event in events.stream {
            switch event {
            case .disconnected:
                return .disconnected // disconnect, retry after fixed cooldown
            case let .removed(disconnect):
                if disconnect {
                    // Do not call disconnect with AccessorySetupKit. We do not have the permission for that anymore.
                    // The device will be disconnected automatically.
                    await peripheral.disconnect()
                }
                break eventLoop
            }
        }

        return .finished  // connected and stream ended (e.g., task got cancelled while waiting for the loop)
    }

    private func runConnectionAttempt(for peripheral: any PairableDevice) async -> ConnectResult {
        do {
            try await peripheral.connect()

            return .connected
        } catch is CancellationError {
            return .end // connect attempt above was cancelled, return
        } catch let BluetoothError.invalidState(state) { // TODO: this is racy if we are running not SpeziBluetooth?
            // TODO: does it make sense to handle this like that?
            Self.logger.warning("Failed connection attempt as bluetooth was not in poweredOn state (actual: \(state)). Aborting.")
            return .end // we will receive another event that will restart us again
        } catch {
            // TODO: generic blueutoh errors?
            Self.logger.warning("Failed connection attempt for device \(peripheral.label): \(error)")
            // TODO: store last connection error in the model!
            return .retry
        }
    }

    private func retrieveDevice(for deviceType: any PairableDevice.Type, using bluetooth: borrowing Bluetooth) async -> (any PairableDevice)? {
        if let peripheral {
            Self.logger.debug("Ignoring request to retrieve device. Device \(peripheral.label), \(peripheral.id) already associated.")
            return peripheral
        }

        let info = info

        Self.logger.debug("Retrieving device for \(info.name), \(info.id)")
        let device = await deviceType.retrieveDevice(from: bluetooth, with: info.id)

        guard let device else {
            Self.logger.warning("Device \(info.id) \(info.name) could not be retrieved!")
            return nil
        }

        assert(peripheral == nil, "Cannot overwrite peripheral. Device \(info) was paired twice. This is a concurrency issue.")
        self.peripheral = device

        return device
    }

    func handleDeviceStateUpdated<Device: PairableDevice>(for device: Device, old oldState: PeripheralState, new newState: PeripheralState) {
        guard device === peripheral else {
            return // TODO: this happens! there is no good way to unsubscribe!
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

            // long-running reconnect (if applicable)
            self.events.continuation.yield(.disconnected)
        default:
            break
        }
    }

    func updateBattery<Device: PairableDevice>(for device: Device, percentage: UInt8) {
        guard device === peripheral else {
            return
        }

        Self.logger.debug("Updated battery level for \(device.label): \(percentage) %")
        info.lastBatteryPercentage = percentage
    }

    private func updateLastSeen<Device: PairableDevice>(for device: Device, lastSeen: Date = .now) {
        guard device === peripheral else {
            return
        }

        info.lastSeen = lastSeen
        if let model = device.deviceInformation.modelNumber {
            info.model = model
        }
        if let batteryPowered = device as? BatteryPoweredDevice,
           let battery = batteryPowered.battery.batteryLevel {
            info.lastBatteryPercentage = battery
        }
    }
}


extension PairableDevice {
    @SpeziBluetooth
    fileprivate static func retrieveDevice(from bluetooth: Bluetooth, with id: UUID) async -> Self? {
        await bluetooth.retrieveDevice(for: id, as: Self.self)
    }
}
