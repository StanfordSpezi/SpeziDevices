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


@available(iOS 18, *)
private final class LoadAccessorySetupKit: Module {
    @Dependency(AccessorySetupKit.self) var accessorySetupKit

    init() {}
}


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
public final class PairedDevices {
    /// Determines if the device discovery sheet should be presented.
    @MainActor public var shouldPresentDevicePairing = false {
        didSet {
            if shouldPresentDevicePairing {
                didEnabledDeviceDiscovery()
            }
        }
    }

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

    @available(iOS 18, *) private var accessorySetup: AccessorySetupKit {
        // we cannot have stored properties with @available declaration. Therefore, we add a level of indirection.
        guard let module = _accessorySetup.first as? LoadAccessorySetupKit else {
            preconditionFailure("\(AccessorySetupKit.self) was not injected into dependency tree.")
        }
        return module.accessorySetupKit
    }

    @MainActor private var modelContainer: ModelContainer?

    /// Determine if Bluetooth is scanning to discovery nearby devices.
    ///
    /// Scanning is automatically started if there hasn't been a paired device or if the discovery sheet is presented.
    @MainActor public var isScanningForNearbyDevices: Bool {
        // TODO: configure if initial search should be enabled (otherwise, we cannot migrate accessory kit!)
        (pairedDevices?.isEmpty == true && !everPairedDevice) || shouldPresentDevicePairing
    }

    private var stateSubscriptionTask: Task<Void, Never>? {
        willSet {
            stateSubscriptionTask?.cancel()
        }
    }


    /// Initialize the Paired Devices Module.
    public required init() {
        if #available(iOS 18, *) {
            __accessorySetup = Dependency {
                // Dynamic dependencies are always loaded independent if the module was already supplied in the environment.
                // Therefore, we create a helper module, that loads the accessory setup kit module.
                LoadAccessorySetupKit()
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

        // We need to detach to not copy task local values
        Task.detached { @Sendable @MainActor in
            self.fetchAllPairedInfos() // TODO: do immediate need to do this in a Task!

            self.syncDeviceIcons() // make sure assets are up to date

            guard !self._pairedDevices.isEmpty else {
                return // no devices paired, no need to power up central
            }

            await self.setupBluetoothStateSubscription()
        }

        if #available(iOS 18, *) {
            setupAccessoryChangeSubscription()
        }
    }

    @MainActor
    func didEnabledDeviceDiscovery() {
        if #available(iOS 18, *) {
            guard let bluetooth else {
                return
            }

            let displayItems: [ASPickerDisplayItem] = bluetooth.configuration.reduce(into: []) { partialResult, descriptor in
                guard let pairableDevice = descriptor.deviceType as? any PairableDevice.Type else {
                    return
                }
                partialResult.append(contentsOf: pairableDevice.assets.map { $0.pickerDisplayItem(for: descriptor.discoveryCriteria) })
            }

            Task {
                do {
                    try await accessorySetup.showPicker(for: displayItems)
                    print("Completed picker!")
                } catch {
                    print("Picker failed: \(error)")
                }
            }
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

        if #available(iOS 18, *) {
            renameAccessory(for: deviceInfo.id, name: name)
        }
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
        if bluetooth?.configuredPairableDevices[Device.deviceTypeIdentifier] == nil {
            logger.warning("""
                           Device \(Device.self) was configured with the PairedDevices module but wasn't configured with the Bluetooth module. \
                           The device won't be able to be retrieved on a fresh app start. Please make sure the device is configured with Bluetooth.
                           """)
        }

        // update name to the latest value
        if let info = _pairedDevices[device.id] {
            info.peripheralName = device.name
            info.icon = Device.assets.firstAsset(for: info) // the asset might have changed
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
            do {
                try await device.connect()
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                logger.warning("Failed connection attempt for device \(device.label). Retrying ...")
                connectionAttempt(for: device)
            }
        }
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
            group.addTask { @Sendable @MainActor in
                do {
                    try await device.connect()
                } catch {
                    if error is CancellationError {
                        self.ongoingPairings.removeValue(forKey: id)?.signalCancellation()
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
                    Task { @MainActor [weak device] in
                        self.ongoingPairings.removeValue(forKey: id)?.signalCancellation()
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

        let deviceInfo = PairedDeviceInfo(
            id: device.id,
            deviceType: Device.deviceTypeIdentifier,
            name: device.label,
            model: device.deviceInformation.modelNumber,
            icon: Device.assets.firstAsset(for: device),
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

        discoveredDevices[deviceInfo.id] = nil

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
    @available(*, deprecated, message: "Please use the async version of this method.") // TODO: really?
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
        if #available(iOS 18, *) {
            try await removeAccessory(for: id) // TODO: are these errors localizable?
        }

        removeDevice(id: id)
    }

    @MainActor
    private func removeDevice(id: UUID) {
        let removed = _pairedDevices.removeValue(forKey: id)
        if let removed {
            modelContainer?.mainContext.delete(removed)
        }


        discoveredDevices.removeValue(forKey: id)
        let device = peripherals.removeValue(forKey: id)

        if let device {
            Task.detached {
                await device.disconnect()
            }
        }

        if _pairedDevices.isEmpty {
            Task {
                await cancelSubscription()
            }
        }
    }
}

// MARK: - Accessory Setup Kit

@available(iOS 18, *)
extension PairedDevices {
    @MainActor
    private func setupAccessoryChangeSubscription() {
        // TODO: not strictly necessary to register here? => slightly delay session activate init in the configure()?
        Task { @MainActor in
            for await change in accessorySetup.accessoryChanges {
                print("We received a change \(change)") // TODO: we need to register the change befor

                switch change { // TODO: is that a good model, we could easily check for bluetoothIdentifier once?
                case let .added(accessory):
                    handledAddedAccessory(accessory)
                case let .changed(accessory):
                    updateAccessory(accessory)
                case let .removed(accessory):
                    handleRemovedAccessory(accessory)
                }
            }
        }
    }

    @MainActor
    private func handledAddedAccessory(_ accessory: ASAccessory) {
        guard let id = accessory.bluetoothIdentifier else {
            return
        }

        guard let deviceType = bluetooth?.configuration.first(where: { descriptor in
            descriptor.discoveryCriteria.discoveryDescriptor == accessory.descriptor
        })?.deviceType as? any PairableDevice.Type else {
            logger.error("Could not match discovery description of paired device: \(id)") // TODO: update
            return
        }
        // TODO: map descriptor back to discovery criteria to retrieve the Device class!

        let deviceInfo = PairedDeviceInfo(
            id: id,
            deviceType: deviceType.deviceTypeIdentifier,
            name: accessory.displayName,
            model: nil, // TODO: this needs to be queried later
            icon: deviceType.assets.firstAsset(name: accessory.displayName) // TODO: that shouldn't be the final solution!
            // TODO: asset should be matched by descriptor!
        )

        persistPairedDevice(deviceInfo) // TODO: we should attempt to connect first, this will connected yes, but not ideal!
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
    private func handleRemovedAccessory(_ accessory: ASAccessory) {
        guard let id = accessory.bluetoothIdentifier else {
            return
        }

        removeDevice(id: id)
    }

    @MainActor
    private func removeAccessory(for id: UUID) async throws {
        guard let accessory = accessorySetup.accessories.first(where: { $0.bluetoothIdentifier == id }) else {
            return
        }

        try await accessorySetup.removeAccessory(accessory)
    }

    @MainActor
    private func renameAccessory(for id: UUID, name: String) {
        guard let accessory = accessorySetup.accessories.first(where: { $0.bluetoothIdentifier == id }) else {
            return
        }

        // TODO: howfeature/accessory-setup-kit does the rename work?
        Task {
            do {
                try await accessorySetup.renameAccessory(accessory) // TODO: what does that trigger?
            } catch {
                print("Error renaming: \(error)") // TODO: update!
            }
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

        let configuredDevices = bluetooth.configuredPairableDevices

        for deviceInfo in _pairedDevices.values {
            guard let deviceType = configuredDevices[deviceInfo.deviceType] else {
                continue
            }

            deviceInfo.icon = deviceType.assets.firstAsset(for: deviceInfo)
        }
    }

    @MainActor
    private func setupBluetoothStateSubscription() async {
        assert(!_pairedDevices.isEmpty, "Bluetooth State subscription doesn't need to be set up without any paired devices.")

        guard let bluetooth, stateSubscriptionTask == nil else {
            return
        }

        self.stateSubscriptionTask = Task.detached { [weak self] in
            for await nextState in await bluetooth.stateSubscription {
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
        await bluetooth.retrieveDevice(for: id, as: Self.self)
    }
}

// swiftlint:disable:this file_length
