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
import SpeziFoundation
import SpeziViews
import SwiftUI


/// Persistently pair with Bluetooth devices and automatically manage connections.
///
/// Use the `PairedDevices` module to discover and pair ``PairedDevices`` and automatically manage connection establishment
/// of connected devices.
/// - Note: Implement your device as a [`BluetoothDevice`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetoothdevice)
///     using [SpeziBluetooth](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth).
///
/// To support `PairedDevices`, you need to adopt the ``PairedDevices`` protocol for your device.
/// Optionally you can adopt ``BatteryPoweredDevice`` if your device supports the `BatteryService`.
/// Once your device is loaded, register it with the `PairedDevices` module by calling the ``configure(device:accessing:_:_:)`` method.
///
/// ```swift
/// import SpeziDevices
///
/// class MyDevice: PairableDevice {
///     @DeviceState(\.id) var id
///     @DeviceState(\.name) var name
///     @DeviceState(\.state) var state
///     @DeviceState(\.advertisementData) var advertisementData
///     @DeviceState(\.nearby) var nearby
///
///     @Service var deviceInformation = DeviceInformationService()
///
///     @DeviceAction(\.connect) var connect
///     @DeviceAction(\.disconnect) var disconnect
///
///     var isInPairingMode: Bool {
///         // determine if a nearby device is in pairing mode
///     }
///
///     @Dependency private var pairedDevices: PairedDevices?
///
///     required init() {}
///
///     func configure() {
///         pairedDevices?.configure(device: self, accessing: $state, $advertisementData, $nearby)
///     }
///
///     func handleSuccessfulPairing() { // called on events where a device can be considered paired (e.g., incoming notifications)
///         pairedDevices?.signalDevicePaired(self)
///     }
/// }
/// ```
///
/// To display and manage paired devices and support adding new paired devices, you can use the full-featured ``DevicesTab`` view.
///
/// ## Topics
///
/// ### Configuring Paired Devices
/// - ``init()``
/// - ``init(_:)``
///
/// ### Register Devices
/// - ``configure(device:accessing:_:_:)``
///
/// ### Pairing Nearby Devices
/// - ``shouldPresentDevicePairing``
/// - ``discoveredDevices``
/// - ``isScanningForNearbyDevices``
/// - ``pair(with:timeout:)``
/// - ``pairedDevices``
///
/// ### Forget Paired Device
/// - ``forgetDevice(id:)``
///
/// ### Manage Paired Devices
/// - ``isPaired(_:)``
/// - ``isConnected(device:)``
/// - ``updateName(for:name:)``
@Observable
public final class PairedDevices {
    /// Determines if the device discovery sheet should be presented.
    @MainActor public var shouldPresentDevicePairing = false
    /// Collection of discovered devices indexed by their Bluetooth identifier.
    @MainActor public private(set) var discoveredDevices: OrderedDictionary<UUID, any PairableDevice> = [:]

    @MainActor private(set) var peripherals: [UUID: any PairableDevice] = [:]

    /// Device Information of paired devices.
    @MainActor public var pairedDevices: [PairedDeviceInfo] {
        get {
            access(keyPath: \.pairedDevices)
            return _pairedDevices.values
        }
        set {
            withMutation(keyPath: \.pairedDevices) {
                _pairedDevices = SavableCollection(newValue)
            }
        }
    }
    @AppStorage @MainActor @ObservationIgnored private var _pairedDevices: SavableCollection<PairedDeviceInfo>

    @MainActor @ObservationIgnored private var pendingConnectionAttempts: [UUID: Task<Void, Never>] = [:]
    @MainActor @ObservationIgnored private var ongoingPairings: [UUID: PairingContinuation] = [:]

    @AppStorage("edu.stanford.spezi.SpeziDevices.ever-paired-once") @MainActor @ObservationIgnored private var everPairedDevice = false


    @Application(\.logger) @ObservationIgnored private var logger

    @Dependency @ObservationIgnored private var bluetooth: Bluetooth?
    @Dependency @ObservationIgnored private var tipKit: ConfigureTipKit

    /// Determine if Bluetooth is scanning to discovery nearby devices.
    ///
    /// Scanning is automatically started if there hasn't been a paired device or if the discovery sheet is presented.
    @MainActor public var isScanningForNearbyDevices: Bool {
        (pairedDevices.isEmpty && !everPairedDevice) || shouldPresentDevicePairing
    }

    private var stateSubscriptionTask: Task<Void, Never>? {
        willSet {
            stateSubscriptionTask?.cancel()
        }
    }


    /// Initialize the Paired Devices Module.
    public required convenience init() {
        self.init("edu.stanford.spezi.SpeziDevices.PairedDevices.devices-default")
    }

    /// Initialize the Paired Devices Module with custom storage key.
    /// - Parameter storageKey: The storage key for storing paired device information.
    public init(_ storageKey: String) {
        self.__pairedDevices = AppStorage(wrappedValue: [], storageKey)
    }


    /// Configures the Module.
    @_documentation(visibility: internal)
    public func configure() {
        guard bluetooth != nil else {
            self.logger.warning("PairedDevices Module initialized without Bluetooth dependency!")
            return // useful for e.g. previews
        }

        // We need to detach to not copy task local values
        Task.detached { @MainActor in
            guard !self.pairedDevices.isEmpty else {
                return // no devices paired, no need to power up central
            }

            await self.setupBluetoothStateSubscription()
        }
    }

    /// Clears all currently stored paired devices.
    @_spi(TestingSupport)
    @MainActor
    public func clearStorage() {
        pairedDevices.removeAll()
    }

    /// Determine if a device is currently connected.
    /// - Parameter device: The Bluetooth device identifier.
    /// - Returns: Returns `true` if the device for the given identifier is currently connected.
    @MainActor
    public func isConnected(device: UUID) -> Bool {
        peripherals[device]?.state == .connected
    }

    /// Determine if a device is paired.
    /// - Parameter device: The device instance.
    /// - Returns: Returns `true` if the given device is paired.
    @MainActor
    public func isPaired<Device: PairableDevice>(_ device: Device) -> Bool {
        pairedDevices.contains { $0.id == device.id }
    }

    /// Update the user-chosen name of a paired device.
    /// - Parameters:
    ///   - deviceInfo: The paired device information for which to update the name.
    ///   - name: The new name.
    @MainActor
    public func updateName(for deviceInfo: PairedDeviceInfo, name: String) {
        deviceInfo.name = name
        flush()
    }

    /// Configure a device to be managed by this PairedDevices instance.
    /// - Parameters:
    ///   - device: The device instance to configure.
    ///   - state: The `@DeviceState` accessor for the `PeripheralState`.
    ///   - advertisements: The `@DeviceState` accessor for the current `AdvertisementData`.
    ///   - nearby: The `@DeviceState` accessor for the `nearby` flag.
    public func configure<Device: PairableDevice>(
        device: Device,
        accessing state: DeviceStateAccessor<PeripheralState>,
        _ advertisements: DeviceStateAccessor<AdvertisementData>,
        _ nearby: DeviceStateAccessor<Bool>
    ) {
        state.onChange { [weak self, weak device] oldValue, newValue in
            if let device {
                await self?.handleDeviceStateUpdated(device, old: oldValue, new: newValue)
            }
        }
        advertisements.onChange(initial: true) { [weak self, weak device] _ in
            guard let device else {
                return
            }
            if device.isInPairingMode {
                await self?.discoveredPairableDevice(device)
            }
        }
        nearby.onChange { [weak self, weak device] nearby in
            if let device, !nearby {
                await self?.handleDiscardedDevice(device)
            }
        }

        if let batteryPowered = device as? any BatteryPoweredDevice {
            batteryPowered.battery.$batteryLevel.onChange { [weak self, weak device] value in
                guard let device, let self else {
                    return
                }
                await updateBattery(for: device, percentage: value)
            }
        }
    }

    @MainActor
    private func handleDeviceStateUpdated<Device: PairableDevice>(_ device: Device, old oldState: PeripheralState, new newState: PeripheralState) {
        switch newState {
        case .connected:
            cancelConnectionAttempt(for: device) // just clear the entry
            updateLastSeen(for: device)
        case .disconnecting:
            if case .connected = oldState {
                updateLastSeen(for: device)
            }
        case .disconnected:
            ongoingPairings.removeValue(forKey: device.id)?.signalDisconnect()

            if case .connected = oldState {
                updateLastSeen(for: device)
            }

            // long-running reconnect (if applicable)
            connectionAttempt(for: device)
        default:
            break
        }
    }

    @MainActor
    private func discoveredPairableDevice<Device: PairableDevice>(_ device: Device) {
        guard discoveredDevices[device.id] == nil else {
            return
        }

        guard !isPaired(device) else {
            return
        }

        self.logger.info(
            "Detected nearby \(Device.self) accessory\(device.advertisementData.manufacturerData.map { " with manufacturer data \($0)" } ?? "")"
        )

        discoveredDevices[device.id] = device
        shouldPresentDevicePairing = true
    }

    @MainActor
    private func updateBattery<Device: PairableDevice>(for device: Device, percentage: UInt8) {
        guard let index = pairedDevices.firstIndex(where: { $0.id == device.id }) else {
            return
        }
        logger.debug("Updated battery level for \(device.label): \(percentage) %")
        pairedDevices[index].lastBatteryPercentage = percentage
        flush()
    }

    @MainActor
    private func updateLastSeen<Device: PairableDevice>(for device: Device, lastSeen: Date = .now) {
        guard let index = pairedDevices.firstIndex(where: { $0.id == device.id }) else {
            return // not paired
        }
        logger.debug("Updated lastSeen for \(device.label): \(lastSeen) %")
        pairedDevices[index].lastSeen = lastSeen
        flush()
    }

    @MainActor
    private func handleDiscardedDevice<Device: PairableDevice>(_ device: Device) {
        // device discovery was cleared by SpeziBluetooth
        self.logger.debug("\(Device.self) \(device.label) was discarded from discovered devices.")
        discoveredDevices[device.id] = nil
    }

    @MainActor
    private func connectionAttempt(for device: some PairableDevice) {
        guard case .poweredOn = bluetooth?.state, isPaired(device) else {
            return
        }
        
        let previousTask = cancelConnectionAttempt(for: device)

        pendingConnectionAttempts[device.id] = Task {
            await previousTask?.value // make sure its ordered
            await device.connect()
        }
    }

    @MainActor
    @discardableResult
    private func cancelConnectionAttempt(for device: some PairableDevice) -> Task<Void, Never>? {
        let task = pendingConnectionAttempts.removeValue(forKey: device.id)
        task?.cancel()
        return task
    }

    @MainActor
    private func flush() {
        _pairedDevices = _pairedDevices // update app storage
    }

    deinit {
        _peripherals.removeAll()
        stateSubscriptionTask = nil
    }
}


extension PairedDevices: Module, EnvironmentAccessible, DefaultInitializable {}

// MARK: - Device Pairing

extension PairedDevices {
    /// Pair with a recently discovered device.
    ///
    /// This method pairs with a currently advertising Bluetooth device.
    /// - Note: The ``PairableDevice/isInPairingMode`` property determines if the device is currently pairable.
    ///
    /// The implementation verifies that the device is ``PairableDevice/isInPairingMode``, is currently disconnected and ``PairableDevice/nearby``.
    /// It automatically connects to the device to start pairing. Pairing has a 15 second timeout by default.
    /// Pairing is considered successful once ``signalDevicePaired(_:)`` is called by the device. It is considered unsuccessful if the device
    /// disconnects prior to this call.
    /// - Important: A successful pairing cannot be determined automatically and is specific to a device. You must manually call
    ///     ``signalDevicePaired(_:)`` to signal that a device is successfully paired (e.g., every time the device sends a notification for
    ///     a given characteristic).
    /// - Parameters:
    ///   - device: The device to pair with this module.
    ///   - timeout: The duration after which the pairing attempt times out.
    /// - Throws: Throws a ``DevicePairingError`` if not successful.
    @MainActor
    public func pair(with device: some PairableDevice, timeout: Duration = .seconds(15)) async throws {
        guard ongoingPairings[device.id] == nil else {
            throw DevicePairingError.busy
        }

        guard device.isInPairingMode else {
            throw DevicePairingError.notInPairingMode
        }

        guard case .disconnected = device.state else {
            throw DevicePairingError.invalidState
        }

        guard device.nearby else {
            throw DevicePairingError.invalidState
        }

        await device.connect()

        let id = device.id
        async let _ = withTimeout(of: timeout) { @MainActor in
            ongoingPairings.removeValue(forKey: id)?.signalTimeout()
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                ongoingPairings[id] = PairingContinuation(continuation)
            }
        } onCancel: {
            Task { @MainActor [weak device] in
                ongoingPairings.removeValue(forKey: id)?.signalCancellation()
                await device?.disconnect()
            }
        }

        // if cancelled the continuation throws an CancellationError
        await registerPairedDevice(device)
    }

    /// Signal that a device is considered paired.
    ///
    /// You call this method from your device implementation on events that indicate that the device was successfully paired.
    /// - Note: This method does nothing if there is currently no ongoing pairing session for a device.
    /// - Parameter device: The device that can be considered paired and might have an ongoing pairing session.
    /// - Returns: Returns `true` if there was an ongoing pairing session and the device is now paired.
    @MainActor
    @discardableResult
    public func signalDevicePaired(_ device: some PairableDevice) -> Bool {
        guard let continuation = ongoingPairings.removeValue(forKey: device.id) else {
            return false
        }
        logger.debug("Device \(device.label), \(device.id) signaled it is fully paired.")
        continuation.signalPaired()
        return true
    }

    @MainActor
    private func registerPairedDevice<Device: PairableDevice>(_ device: Device) async {
        everPairedDevice = true

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
        peripherals[device.id] = device

        self.logger.debug("Device \(device.label) with id \(device.id) is now paired!")

        if stateSubscriptionTask == nil {
            await setupBluetoothStateSubscription()
        }
    }

    /// Forget a paired device.
    /// - Parameter id: The Bluetooth peripheral identifier of a paired device.
    @MainActor
    public func forgetDevice(id: UUID) {
        pairedDevices.removeAll { info in
            info.id == id
        }

        discoveredDevices.removeValue(forKey: id)
        let device = peripherals.removeValue(forKey: id)
        if let device {
            Task {
                await device.disconnect()
            }
        }

        if pairedDevices.isEmpty {
            Task {
                await cancelSubscription()
            }
        }
    }
}


// MARK: - Paired Peripheral Management

extension PairedDevices {
    @MainActor
    private func setupBluetoothStateSubscription() async {
        assert(!pairedDevices.isEmpty, "Bluetooth State subscription doesn't need to be set up without any paired devices.")

        guard let bluetooth else {
            return
        }

        // If Bluetooth is currently turned off in control center or not authorized anymore, we would want to keep central allocated
        // such that we are notified about the bluetooth state changing.
        await bluetooth.powerOn()

        self.stateSubscriptionTask = Task.detached { [weak self] in
            for await nextState in await bluetooth.stateSubscription {
                guard let self else {
                    return
                }
                await self.handleBluetoothStateChanged(nextState)
            }
        }

        if case .poweredOn = bluetooth.state {
            await self.handleCentralPoweredOn()
        }
    }

    @MainActor
    private func cancelSubscription() async {
        assert(pairedDevices.isEmpty, "Bluetooth State subscription was tried to be cancelled even though devices were still paired.")
        assert(peripherals.isEmpty, "Peripherals were unexpectedly not empty.")

        stateSubscriptionTask = nil
        await bluetooth?.powerOff()
    }

    @MainActor
    private func handleBluetoothStateChanged(_ state: BluetoothState) async {
        logger.debug("Bluetooth Module state is now \(state)")

        switch state {
        case .poweredOn:
            await handleCentralPoweredOn()
        default:
            for device in peripherals.values {
                cancelConnectionAttempt(for: device)
            }
            peripherals.removeAll()
        }
    }

    @MainActor
    private func handleCentralPoweredOn() async {
        guard let bluetooth else {
            return
        }

        guard case .poweredOn = bluetooth.state else {
            return
        }

        // we just reuse the configured Bluetooth devices
        let configuredDevices = bluetooth.configuredPairableDevices

        await withDiscardingTaskGroup { group in
            for deviceInfo in self.pairedDevices {
                group.addTask { @MainActor in
                    guard self.peripherals[deviceInfo.id] == nil else {
                        return
                    }

                    guard let deviceType = configuredDevices[deviceInfo.deviceType] else {
                        self.logger.error("Unsupported device type \"\(deviceInfo.deviceType)\" for paired device \(deviceInfo.name).")
                        return
                    }
                    await self.handleDeviceRetrieval(for: deviceInfo, deviceType: deviceType)
                }
            }
        }
    }

    @MainActor
    private func handleDeviceRetrieval(for deviceInfo: PairedDeviceInfo, deviceType: any PairableDevice.Type) async {
        guard let bluetooth else {
            return
        }

        let device = await deviceType.retrieveDevice(from: bluetooth, with: deviceInfo.id)

        guard let device else {
            self.logger.warning("Device \(deviceInfo.id) \(deviceInfo.name) could not be retrieved!")
            deviceInfo.notLocatable = true
            return
        }

        assert(self.peripherals[device.id] == nil, "Cannot overwrite peripheral. Device \(deviceInfo) was paired twice.")
        self.peripherals[device.id] = device

        connectionAttempt(for: device)
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

// swiftlint:disable:this file_length
