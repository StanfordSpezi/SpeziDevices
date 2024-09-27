//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import AccessorySetupKit
import OrderedCollections
import Spezi
import SpeziBluetooth
import SpeziBluetoothServices
@_spi(TestingSupport) import SpeziFoundation
import SpeziViews
import SwiftData
import SwiftUI


// TODO: support for migration within SpeziDevices! (maybe an alert with "Not Now"/"Migrate" buttons) if not now, have an option in settings?
//  => is it enough to destroy any CBCentralManager instances before migration or are we never allowed to instantiate one.


/// Persistently pair with Bluetooth devices and automatically manage connections.
///
/// Use the `PairedDevices` module to discover and pair ``PairableDevice``s and automatically manage connection establishment
/// of connected devices.
/// - Note: Implement your device as a [`BluetoothDevice`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetoothdevice)
///     using [SpeziBluetooth](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth).
///
/// To support `PairedDevices`, you need to adopt the ``PairableDevice`` protocol for your device.
/// Optionally you can adopt ``BatteryPoweredDevice`` if your device supports the
/// [`BatteryService`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetoothservices/batteryservice).
/// Once your device is loaded, register it with the `PairedDevices` module by calling the ``configure(device:accessing:_:_:)`` method.
///
/// - Important: Don't forget to configure the `PairedDevices` module in
///   your [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).
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
/// - Tip: To display and manage paired devices and support adding new paired devices, you can use the full-featured
/// [`DevicesView`](https://swiftpackageindex.com/stanfordspezi/spezidevices/documentation/spezidevicesui/devicesview).
///
/// ## Topics
///
/// ### Configuring Paired Devices
/// - ``init()``
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
public final class PairedDevices { // swiftlint:disable:this type_body_length
    /// Determines if the device discovery sheet should be presented.
    ///
    /// This property is never set to true if the AccessorySetupKit is used for device discovery and pairing. In cases where the framework is not available or not configured,
    /// this property will be set to true to present a fallback way for discovering accessories.
    @MainActor public var shouldPresentDevicePairing = false

    /// Collection of discovered devices indexed by their Bluetooth identifier.
    @MainActor public private(set) var discoveredDevices: OrderedDictionary<UUID, any PairableDevice> = [:]
    /// The collection of paired devices that are persisted on disk.
    @MainActor public var pairedDevices: [PairedDeviceInfo]? { // swiftlint:disable:this discouraged_optional_collection
        didLoadDevices
            ? Array(_pairedDevices.values)
            : nil
    }

    @MainActor private var _pairedDevices: OrderedDictionary<UUID, PairedDeviceInfo> = [:]
    @MainActor private var didLoadDevices = false

    /// Bluetooth Peripheral instances of paired devices.
    @MainActor private(set) var peripherals: [UUID: any PairableDevice] = [:]

    @MainActor @ObservationIgnored private var pendingConnectionAttempts: [UUID: Task<Void, Never>] = [:]
    @MainActor @ObservationIgnored private var ongoingPairings: [UUID: PairingContinuation] = [:]

    @AppStorage("edu.stanford.spezi.SpeziDevices.ever-paired-once") @MainActor @ObservationIgnored private var everPairedDevice = false


    @Application(\.logger) @ObservationIgnored private var logger

    @Dependency(Bluetooth.self) @ObservationIgnored private var bluetooth: Bluetooth?
    @Dependency(ConfigureTipKit.self) @ObservationIgnored private var tipKit

    @Dependency @ObservationIgnored private var _accessorySetup: [any Module]

    @available(iOS 18, *) private var accessorySetup: AccessorySetupKit? {
        // we cannot have stored properties with @available. Therefore, we add a level of indirection.
        guard let module = _accessorySetup.first else {
            return nil
        }
        guard let loadASKit = module as? LoadAccessorySetupKit else {
            preconditionFailure("\(LoadAccessorySetupKit.self) was not injected into dependency tree.")
        }
        return loadASKit.accessorySetupKit
    }

    @MainActor private var modelContainer: ModelContainer?

    /// Determine if Bluetooth is scanning to discovery nearby devices.
    ///
    /// Scanning is automatically started if there hasn't been a paired device or if the discovery sheet is presented.
    @MainActor public var isScanningForNearbyDevices: Bool {
        let shouldAutoStartSearching = pairedDevices?.isEmpty == true && !everPairedDevice
        return if #available(iOS 18, *) {
            shouldPresentDevicePairing || (accessorySetup == nil && shouldAutoStartSearching)
        } else {
            shouldPresentDevicePairing || shouldAutoStartSearching
        }
    }

    private var stateSubscriptionTask: Task<Void, Never>? {
        willSet {
            stateSubscriptionTask?.cancel()
        }
    }


    /// Initialize the Paired Devices Module.
    public required init() {
        if #available(iOS 18, *) {
            if AccessorySetupKit.supportedProtocols.contains(.bluetooth) {
                __accessorySetup = Dependency {
                    // Dynamic dependencies are always loaded independent if the module was already supplied in the environment.
                    // Therefore, we create a helper module, that loads the accessory setup kit module.
                    LoadAccessorySetupKit()
                }
            }
        }
    }


    /// Configures the Module.
    @_documentation(visibility: internal)
    @MainActor
    public func configure() {
        if bluetooth == nil {
            self.logger.warning("PairedDevices Module initialized without Bluetooth dependency!")
        }

        let configuration: ModelConfiguration
#if targetEnvironment(simulator)
        configuration = ModelConfiguration(isStoredInMemoryOnly: true)
#else
        let storageUrl = URL.documentsDirectory.appending(path: "edu.stanford.spezidevices.paired-devices.sqlite")
        configuration = ModelConfiguration(url: storageUrl)
#endif

        do {
            self.modelContainer = try ModelContainer(for: PairedDeviceInfo.self, configurations: configuration)
        } catch {
            self.modelContainer = nil
            self.logger.error("PairedDevices failed to initialize ModelContainer: \(error)")
        }

        self.fetchAllPairedInfos()
        self.syncDeviceIcons() // make sure assets are up to date

        var powerUpUsingASKit = false

        if #available(iOS 18, *) {
            if accessorySetup != nil {
                setupAccessoryChangeSubscription()
                powerUpUsingASKit = true
            } else {
                logger.info("AccessorySetupKit is supported by the platform but `NSAccessorySetupKitSupports` doesn't declare support for Bluetooth.")
            }
        }

        // We use the ASKit activate event to power up the central if there are paired devices as we need control over it.
        if !powerUpUsingASKit && !self._pairedDevices.isEmpty {
            // We need to detach to not copy task local values
            Task.detached { @Sendable @MainActor in
                guard !self._pairedDevices.isEmpty else {
                    return // no devices paired, no need to power up central
                }

                await self.setupBluetoothStateSubscription()
            }
        }
    }
    
    /// Show the accessory discovery picker.
    ///
    /// Depending on availability, this method presents the discovery sheet of the AccessorySetupKit. If not available, this method sets ``shouldPresentDevicePairing`` to `true`
    /// which should be used to present the `AccessorySetupSheet` from `SpeziDevicesUI`.
    @MainActor
    public func showAccessoryDiscovery() {
        if #available(iOS 18, *), accessorySetup != nil {
            showAccessorySetupPicker()
        } else {
            shouldPresentDevicePairing = true
        }
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
        _pairedDevices[device.id] != nil
    }

    /// Update the user-chosen name of a paired device.
    /// - Parameters:
    ///   - deviceInfo: The paired device information for which to update the name.
    ///   - name: The new name.
    @MainActor
    public func updateName(for deviceInfo: PairedDeviceInfo, name: String) {
        logger.debug("Updated name for paired device \(deviceInfo.id): \(name) %")
        deviceInfo.name = name
    }

    /// Configure a device to be managed by this PairedDevices instance.
    /// - Parameters:
    ///   - device: The device instance to configure.
    ///   - state: The `@DeviceState` accessor for the `PeripheralState`.
    ///   - advertisements: The `@DeviceState` accessor for the current `AdvertisementData`.
    ///   - nearby: The `@DeviceState` accessor for the `nearby` flag.
    @MainActor
    public func configure<Device: PairableDevice>(
        device: Device,
        accessing state: DeviceStateAccessor<PeripheralState>,
        _ advertisements: DeviceStateAccessor<AdvertisementData>,
        _ nearby: DeviceStateAccessor<Bool>
    ) {
        if bluetooth?.pairableDevice(identifier: Device.deviceTypeIdentifier) == nil {
            logger.warning("""
                           Device \(Device.self) was configured with the PairedDevices module but wasn't configured with the Bluetooth module. \
                           The device won't be able to be retrieved on a fresh app start. Please make sure the device is configured with Bluetooth.
                           """)
        }

        // update name to the latest value
        if let info = _pairedDevices[device.id] {
            info.peripheralName = device.name
            info.icon = Device.appearance.deviceIcon(variantId: info.variantIdentifier) // the asset might have changed
        }

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

        logger.debug("Registered device \(device.label), \(device.id) with PairedDevices")
    }

    @MainActor
    private func handleDeviceStateUpdated<Device: PairableDevice>(
        _ device: Device,
        old oldState: PeripheralState,
        new newState: PeripheralState
    ) {
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
            let restored = connectionAttempt(for: device)
            logger.debug("Restored connection attempt for device \(device.label), \(device.id) after disconnect.")
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
            "Detected nearby \(Device.self) accessory\(device.advertisementData.manufacturerData.map { " with manufacturer data \($0.debugDescription)" } ?? "")"
        )

        discoveredDevices[device.id] = device
        shouldPresentDevicePairing = true
    }

    @MainActor
    private func updateBattery<Device: PairableDevice>(for device: Device, percentage: UInt8) {
        guard let deviceInfo = _pairedDevices[device.id] else {
            return
        }
        logger.debug("Updated battery level for \(device.label): \(percentage) %")
        deviceInfo.lastBatteryPercentage = percentage
    }

    @MainActor
    private func updateLastSeen<Device: PairableDevice>(for device: Device, lastSeen: Date = .now) {
        guard let deviceInfo = _pairedDevices[device.id] else {
            return
        }
        logger.debug("Updated lastSeen for \(device.label): \(lastSeen) %")
        deviceInfo.lastSeen = lastSeen
        if let model = device.deviceInformation.modelNumber {
            deviceInfo.model = model
        }
        if let batteryPowered = device as? BatteryPoweredDevice,
           let battery = batteryPowered.battery.batteryLevel {
            deviceInfo.lastBatteryPercentage = battery
        }
    }

    @MainActor
    private func handleDiscardedDevice<Device: PairableDevice>(_ device: Device) {
        // device discovery was cleared by SpeziBluetooth
        self.logger.debug("\(Device.self) \(device.label) was discarded from discovered devices.")
        discoveredDevices[device.id] = nil
    }

    @MainActor
    @discardableResult
    private func connectionAttempt(for device: some PairableDevice) -> Bool {
        guard case .poweredOn = bluetooth?.state, isPaired(device) else {
            return false
        }
        
        let previousTask = cancelConnectionAttempt(for: device)

        pendingConnectionAttempts[device.id] = Task { @SpeziBluetooth in
            await previousTask?.value // make sure its ordered
            guard !Task.isCancelled else {
                return
            }
            do {
                try await device.connect()
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                logger.warning("Failed connection attempt for device \(device.label). Retrying ...")
                await connectionAttempt(for: device)
            }
        }

        return true
    }

    @MainActor
    @discardableResult
    private func cancelConnectionAttempt(for device: some PairableDevice) -> Task<Void, Never>? {
        let task = pendingConnectionAttempts.removeValue(forKey: device.id)
        task?.cancel()
        return task
    }

    deinit {
        _peripherals.removeAll()
        stateSubscriptionTask = nil
    }
}


extension PairedDevices: Module, EnvironmentAccessible, DefaultInitializable, @unchecked Sendable {}

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

        let id = device.id

        // race timeout against the tasks below
        async let _ = await withTimeout(of: timeout) { @MainActor in
            _ = self.ongoingPairings.removeValue(forKey: id)?.signalTimeout()
        }

        try await withThrowingDiscardingTaskGroup { group in
            // connect task
            group.addTask { @Sendable @SpeziBluetooth in
                do {
                    try await device.connect()
                } catch {
                    if error is CancellationError {
                        await MainActor.run {
                            self.ongoingPairings.removeValue(forKey: id)?.signalCancellation()
                        }
                    }

                    throw error
                }
            }

            // pairing task
            group.addTask { @Sendable @MainActor in
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        self.ongoingPairings[id] = PairingContinuation(continuation)
                    }
                } onCancel: {
                    Task { @SpeziBluetooth [weak device] in
                        await MainActor.run {
                            self.ongoingPairings.removeValue(forKey: id)?.signalCancellation()
                        }
                        await device?.disconnect()
                    }
                }
            }
        }


        // the task group above should exit with a CancellationError anyways, but safe to double check here
        guard !Task.isCancelled else {
            throw CancellationError()
        }

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

        let (appearance, variantId) = Device.appearance.appearance { variant in
            variant.criteria.matches(name: device.name, advertisementData: device.advertisementData)
        }

        let deviceInfo = PairedDeviceInfo(
            id: device.id,
            deviceType: Device.deviceTypeIdentifier,
            name: appearance.name,
            model: device.deviceInformation.modelNumber,
            icon: appearance.icon,
            variantIdentifier: variantId,
            batteryPercentage: batteryLevel
        )

        assert(peripherals[device.id] == nil, "Cannot overwrite peripheral. Device \(deviceInfo) was paired twice.")
        peripherals[device.id] = device

        persistPairedDevice(deviceInfo)
    }

    @MainActor
    private func persistPairedDevice(_ deviceInfo: PairedDeviceInfo) {
        _pairedDevices[deviceInfo.id] = deviceInfo
        if let modelContainer {
            modelContainer.mainContext.insert(deviceInfo)
        } else {
            logger.warning("PairedDevice \(deviceInfo.name), \(deviceInfo.id) could not be persisted on disk due to missing ModelContainer!")
        }

        discoveredDevices.removeValue(forKey: deviceInfo.id)

        self.logger.debug("Device \(deviceInfo.name) with id \(deviceInfo.id) is now paired!")

        if stateSubscriptionTask == nil {
            Task {
                await setupBluetoothStateSubscription()
            }
        }
    }

    /// Forget a paired device.
    /// - Parameter id: The Bluetooth peripheral identifier of a paired device.
    @MainActor
    @available(*, deprecated, message: "Please use the async version of this method.")
    public func forgetDevice(id: UUID) {
        Task {
            do {
                try await forgetDevice(id: id)
            } catch {
                logger.error("Failed to forget device \(id): \(error)")
            }
        }
    }

    /// Forget a paired device.
    /// - Parameter id: The Bluetooth peripheral identifier of a paired device.
    @MainActor
    public func forgetDevice(id: UUID) async throws {
        // TODO: device stays retrieved after forgetting!
        try await removeDevice(id: id) {
            if #available(iOS 18, *) {
                try await removeAccessory(for: id)
            }
        }
    }

    @MainActor
    private func removeDevice(id: UUID, additionalAction: () async throws -> Void = {}) async rethrows {
        // we need to remove this first, the disconnect below (and the one triggered by the AccessorySetupKit) will subsequently
        // call our stateChange handler for the device state. If we keep the entry, the connection attempt task would be restored.
        let removed = _pairedDevices.removeValue(forKey: id)

        if let device = peripherals[id] {
            await cancelConnectionAttempt(for: device)?.value

            if device.state != .disconnected {
                await device.disconnect()
            }
        }

        do {
            try await additionalAction()
        } catch {
            // restore state again
            _pairedDevices[id] = removed
            if let device = peripherals[id] {
                connectionAttempt(for: device)
            }
            throw error
        }

        // finally remove the data
        if let removed {
            modelContainer?.mainContext.delete(removed)
        }

        discoveredDevices.removeValue(forKey: id)
        let device = peripherals.removeValue(forKey: id)

        if let device, device.state != .disconnected {
            await cancelConnectionAttempt(for: device)?.value
            await device.disconnect()
        }

        if self._pairedDevices.isEmpty {
            await self.cancelSubscription()
        }
    }
}


// MARK: - Paired Peripheral Management

extension PairedDevices {
    @MainActor
    private func fetchAllPairedInfos() {
        defer {
            didLoadDevices = true
        }

        guard let modelContainer else {
            return
        }

        let context = modelContainer.mainContext
        var allPairedDevices = FetchDescriptor<PairedDeviceInfo>(
            sortBy: [SortDescriptor(\.pairedAt)]
        )
        allPairedDevices.includePendingChanges = true

        do {
            let pairedDevices = try context.fetch(allPairedDevices)
            self._pairedDevices = pairedDevices.reduce(into: [:]) { partialResult, deviceInfo in
                partialResult[deviceInfo.id] = deviceInfo
            }
            logger.debug("Initialized PairedDevices with \(self._pairedDevices.count) paired devices!")
        } catch {
            logger.error("Failed to fetch paired device info from disk: \(error)")
        }
    }

    @MainActor
    func refreshPairedDevices() throws {
        _pairedDevices.removeAll()
        didLoadDevices = false

        if let modelContainer, modelContainer.mainContext.hasChanges {
            try modelContainer.mainContext.save()
        }

        fetchAllPairedInfos()
    }

    @MainActor
    private func syncDeviceIcons() {
        guard let bluetooth else {
            return
        }

        let configuredDevices = bluetooth.configuredPairableDevices()

        for deviceInfo in _pairedDevices.values {
            guard let deviceType = configuredDevices[deviceInfo.deviceType] else {
                continue
            }

            if let migration = deviceType as? DeviceVariantMigration.Type,
               case .variants = deviceType.appearance,
               deviceInfo.variantIdentifier == nil {
                let (appearance, variantId) = migration.selectAppearance(for: deviceInfo)
                deviceInfo.variantIdentifier = variantId
                deviceInfo.icon = appearance.icon
            } else {
                deviceInfo.icon = deviceType.appearance.deviceIcon(variantId: deviceInfo.variantIdentifier)
            }
        }
    }

    @MainActor
    private func setupBluetoothStateSubscription() async {
        assert(!_pairedDevices.isEmpty, "Bluetooth State subscription doesn't need to be set up without any paired devices.")

        guard let bluetooth, stateSubscriptionTask == nil else {
            return
        }

        let subscriptions = await bluetooth.stateSubscription
        self.stateSubscriptionTask = Task.detached { [weak self] in
            for await nextState in subscriptions {
                guard let self else {
                    return
                }
                await self.handleBluetoothStateChanged(nextState)
            }
        }

        // If Bluetooth is currently turned off in control center or not authorized anymore, we would want to keep central allocated
        // such that we are notified about the bluetooth state changing.
        await bluetooth.powerOn()

        if case .poweredOn = bluetooth.state {
            await self.handleCentralPoweredOn()
        }
    }

    @MainActor
    private func cancelSubscription() async {
        assert(_pairedDevices.isEmpty, "Bluetooth State subscription was tried to be cancelled even though devices were still paired.")
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
            await withDiscardingTaskGroup { group in
                for device in peripherals.values {
                    group.addTask {
                        await self.cancelConnectionAttempt(for: device)
                    }
                }
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
        let configuredDevices = bluetooth.configuredPairableDevices()

        await withDiscardingTaskGroup { group in
            for deviceInfo in self._pairedDevices.values {
                group.addTask { @Sendable @MainActor in
                    guard self.peripherals[deviceInfo.id] == nil else {
                        return
                    }

                    guard let deviceType = configuredDevices[deviceInfo.deviceType] else {
                        self.logger.error("Unsupported device type \"\(deviceInfo.deviceType)\" for paired device \(deviceInfo.name).")
                        deviceInfo.notLocatable = true
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

        logger.debug("Retrieving device for \(deviceInfo.name), \(deviceInfo.id)")
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

// MARK: - Accessory Setup Kit

@available(iOS 18, *)
extension PairedDevices {
    /// Determine if the accessory picker of the AccessorySetupKit is currently being presented.
    @MainActor public var accessoryPickerPresented: Bool {
        accessorySetup?.pickerPresented ?? false
    }
    
    /// Retrieve the `ASAccessory` for a device identifier.
    /// - Parameter deviceId: The identifier for a paired bluetooth device.
    /// - Returns: The accessory or `nil` if the device is not managed by the AccessorySetupKit.
    @_spi(Internal)
    @MainActor
    public func accessory(for deviceId: UUID) -> ASAccessory? {
        if let accessorySetup {
            accessorySetup.accessories.first { accessory in
                accessory.bluetoothIdentifier == deviceId
            }
        } else {
            nil
        }
    }

    @MainActor
    private func setupAccessoryChangeSubscription() {
        guard let accessorySetup else {
            return // method is not called if this is not available
        }

        let changes = accessorySetup.accessoryChanges

        Task.detached { @Sendable @MainActor [weak self] in
            for await change in changes {
                guard let self else {
                    break
                }

                logger.debug("Received accessory change: \(String(describing: change))")

                switch change {
                case .available:
                    await handleSessionAvailable()
                case let .added(accessory):
                    handledAddedAccessory(accessory)
                case let .changed(accessory):
                    updateAccessory(accessory)
                case let .removed(accessory):
                    await handleRemovedAccessory(accessory)
                }
            }
        }
    }

    @MainActor
    private func handleSessionAvailable() async {
        guard let accessorySetup else {
            return
        }

        for accessory in accessorySetup.accessories {
            guard let uuid = accessory.bluetoothIdentifier else {
                continue
            }

            guard _pairedDevices[uuid] == nil else {
                continue // we are already paired
            }

            logger.debug("Found available accessory that hasn't been paired.")
            handledAddedAccessory(accessory)
        }

        // TODO: support migration here? devices that are added but not found in accessory setup kit!

        if !self._pairedDevices.isEmpty {
            await self.setupBluetoothStateSubscription()
        }
    }

    @MainActor
    func showAccessorySetupPicker() {
        // TODO: the picker disables powers off the central. are we still connecting afterwards?
        guard let bluetooth else {
            preconditionFailure("Tried to show accessory setup picker but Bluetooth module was not configured.")
        }

        guard let accessorySetup else {
            preconditionFailure("Tried to show accessory setup picker but AccessorySetupKit module was not configured.")
        }

        let displayItems: [ASPickerDisplayItem] = bluetooth.configuration.reduce(into: []) { partialResult, descriptor in
            guard descriptor.deviceType is any PairableDevice.Type else {
                return
            }

            switch descriptor.deviceType.appearance {
            case let .appearance(appearance):
                let descriptor = descriptor.discoveryCriteria.discoveryDescriptor
                let image = appearance.icon.uiImageScaledForAccessorySetupKit()
                partialResult.append(ASPickerDisplayItem(name: appearance.name, productImage: image, descriptor: descriptor))
            case let .variants(_, variants):
                for variant in variants {
                    let descriptor = descriptor.discoveryCriteria.discoveryDescriptor
                    variant.criteria.apply(to: descriptor)

                    let image = variant.icon.uiImageScaledForAccessorySetupKit()
                    partialResult.append(ASPickerDisplayItem(name: variant.name, productImage: image, descriptor: descriptor))
                }
                // TODO: reduce some of the code complexity here, move things into extensions!

                // with the AccessorySetupKit we can only pair known device variants.
            }
        }

        Task {
            do {
                try await accessorySetup.showPicker(for: displayItems)
                logger.debug("Finished showing setup picker.")
            } catch {
                logger.error("Failed to show setup picker: \(error)")
            }
        }
    }

    @MainActor
    private func handledAddedAccessory(_ accessory: ASAccessory) {
        guard let id = accessory.bluetoothIdentifier else {
            return
        }

        guard let deviceType = bluetooth?.pairableDevice(matches: accessory.descriptor) else {
            logger.error("Could not match discovery description of paired device: \(id)")
            return
        }

        let (appearance, variantId) = deviceType.appearance.appearance { variant in
            variant.criteria.matches(descriptor: accessory.descriptor)
        }

        let deviceInfo = PairedDeviceInfo(
            id: id,
            deviceType: deviceType.deviceTypeIdentifier,
            name: accessory.displayName, // should be the same as appearance.name, however, user might have renamed it already
            model: nil,
            icon: appearance.icon,
            variantIdentifier: variantId
        )


        if stateSubscriptionTask != nil { // if the task is running, bluetooth is powered on
            Task {
                // Bluetooth module turns off and back on again when accessory kit is used. Therefore, this accessory might already be
                // retrieved due to the state change.
                guard self.peripherals[id] == nil else {
                    return
                }

                await handleDeviceRetrieval(for: deviceInfo, deviceType: deviceType)
            }
        }

        // otherwise device retrieval is handled once bluetooth is powered on
        persistPairedDevice(deviceInfo)
    }

    @MainActor
    private func updateAccessory(_ accessory: ASAccessory) {
        guard let id = accessory.bluetoothIdentifier,
              let pairedDevice = _pairedDevices[id] else {
            return // unknown device or not a bluetooth device
        }

        // allow to sync back name!
        pairedDevice.name = accessory.displayName
    }

    @MainActor
    private func handleRemovedAccessory(_ accessory: ASAccessory) async {
        guard let id = accessory.bluetoothIdentifier else {
            return
        }

        await removeDevice(id: id) {}
    }

    @MainActor
    private func removeAccessory(for id: UUID) async throws {
        guard let accessorySetup else {
            return // we wouldn't receive the event if it the module wouldn't be configured
        }

        guard let accessory = accessorySetup.accessories.first(where: { $0.bluetoothIdentifier == id }) else {
            return
        }

        try await accessorySetup.removeAccessory(accessory)
        /*
         TODO: remove!
         Received accessory change: .removed(ASAccessory: ID 2C96BB01-D3BE-47F9-8EC6-91E4E870CEE1, name 'EVOLV', btID 3e1851c3-5ce3-b407-5a3c-7a7b04fdafb4, state Authorized, descriptor ASDiscoveryDescriptor: Supports 0x2 < BluetoothPairingLE >, LocalName BLEsmart_0000021F, ServiceUUID Blood Pressure)
         BluetoothManager central state is now poweredOff
         OmronBloodPressureCuff changed state to disconnected.
         Disconnecting peripheral 'EVOLV'@3E1851C3-5CE3-B407-5A3C-7A7B04FDAFB4 ...
         >>>API MISUSE: <CBCentralManager: 0x302cde7e0> can only accept this command while in the powered on state<<<
         Bluetooth Module state is now poweredOff
         Not deallocating central. Devices are still associated: discovered: 0, retrieved: 1
         */
    }
    
    /// Rename an accessory.
    ///
    /// This will present a picker from the AccessorySetupKit to rename the accessory.
    /// - Parameter accessory: The accessory.
    @MainActor
    @_spi(Internal)
    public func renameAccessory(for accessory: ASAccessory) async throws {
        guard let accessorySetup else {
            return // we wouldn't receive the event if it the module wouldn't be configured
        }

        do {
            try await accessorySetup.renameAccessory(accessory)
        } catch {
            logger.error("Failed to rename accessory managed by AccessorySetupKit (\(accessory)): \(error)")
            throw error
        }
    }
}


extension Bluetooth {
    fileprivate nonisolated func configuredPairableDevices() -> [String: any PairableDevice.Type] {
        configuration.reduce(into: [:]) { partialResult, descriptor in
            guard let pairableDevice = descriptor.deviceType as? any PairableDevice.Type else {
                return
            }
            partialResult[pairableDevice.deviceTypeIdentifier] = pairableDevice
        }
    }

    fileprivate nonisolated func pairableDevice(identifier deviceTypeIdentifier: String) -> (any PairableDevice.Type)? {
        for descriptor in self.configuration {
            guard let pairableDevice = descriptor.deviceType as? any PairableDevice.Type,
                  pairableDevice.deviceTypeIdentifier == deviceTypeIdentifier else {
                continue
            }

            return pairableDevice
        }

        return nil
    }

    @available(iOS 18, *)
    fileprivate nonisolated func pairableDevice(matches discoveryDescriptor: ASDiscoveryDescriptor) -> (any PairableDevice.Type)? {
        for descriptor in self.configuration {
            guard let pairableDevice = descriptor.deviceType as? any PairableDevice.Type,
                  descriptor.discoveryCriteria.matches(descriptor: discoveryDescriptor) else {
                continue
            }

            return pairableDevice
        }

        return nil
    }
}


extension PairableDevice {
    fileprivate static func retrieveDevice(from bluetooth: Bluetooth, with id: UUID) async -> Self? {
        await bluetooth.retrieveDevice(for: id, as: Self.self)
    }
}

// swiftlint:disable:this file_length
