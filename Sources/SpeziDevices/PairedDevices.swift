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


// TODO: support for migration within SpeziDevices (just upon app launch)! (maybe an alert with "Not Now"/"Migrate" buttons) if not now, have an option in settings?
//  => is it enough to destroy any CBCentralManager instances before migration or are we never allowed to instantiate one.
// TODO: the picker disables powers off the central. are we still connecting with other devices afterwards?


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
/// - ``forgetDevice(id:)-1zdk2``
///
/// ### Manage Paired Devices
/// - ``isPaired(_:)``
/// - ``isConnected(device:)``
/// - ``updateName(for:name:)``
@Observable
public final class PairedDevices { // swiftlint:disable:this type_body_length
    // TODO: update docs!
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

    /// Determines if the device discovery sheet should be presented.
    ///
    /// This property is never set to `true` if the AccessorySetupKit is used for device discovery and pairing. In cases where the framework is not available or not configured,
    /// this property will be set to `true` to present a fallback way for discovering accessories.
    @MainActor public var shouldPresentDevicePairing = false

    @MainActor private var _discoveredDevices: OrderedDictionary<UUID, DiscoveredDevice> = [:]
    /// Collection of discovered devices indexed by their Bluetooth identifier.
    @MainActor public var discoveredDevices: [any PairableDevice] {
        _discoveredDevices.values.map { $0.device }
    }


    @MainActor private var _newPairedDevices: OrderedDictionary<UUID, PairedDevice> = [:]
    /// The collection of paired devices that are persisted on disk.
    @MainActor public var pairedDevices: [PairedDeviceInfo]? { // swiftlint:disable:this discouraged_optional_collection
        didLoadDevices
        ? Array(_newPairedDevices.values.map { $0.info })
        : nil
    }

    @MainActor private var didLoadDevices = false

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

    private var scheduledPowerOffTask: Task<Void, Never>? {
        willSet {
            scheduledPowerOffTask?.cancel()
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
        if !powerUpUsingASKit && !self._newPairedDevices.isEmpty {
            // We need to detach to not copy task local values
            Task.detached { @Sendable @MainActor in
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
        _newPairedDevices[device]?.peripheral?.state == .connected
    }

    /// Determine if a device is paired.
    /// - Parameter device: The device instance.
    /// - Returns: Returns `true` if the given device is paired.
    @MainActor
    public func isPaired<Device: PairableDevice>(_ device: Device) -> Bool {
        _newPairedDevices[device.id] != nil
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
        // this might be called for a device we are currently discovering, or for a paired device we retrieved

        if bluetooth?.pairableDevice(identifier: Device.deviceTypeIdentifier) == nil {
            logger.warning("""
                           Device \(Device.self) was configured with the PairedDevices module but wasn't configured with the Bluetooth module. \
                           The device won't be able to be retrieved on a fresh app start. Please make sure the device is configured with Bluetooth.
                           """)
        }

        if let pairedDevice = _newPairedDevices[device.id] {
            // we retrieved the device of a paired device
            pairedDevice.updateUponConfiguration(of: device)
        }

        state.onChange { @MainActor [weak self, weak device] oldValue, newValue in
            guard let self, let device else {
                return
            }

            if let pairedDevice = _newPairedDevices[device.id] {
                pairedDevice.handleDeviceStateUpdated(for: device, old: oldValue, new: newValue)
            }
            if let discoveredDevice = _discoveredDevices[device.id] {
                discoveredDevice.handleDeviceStateUpdated(for: device, newValue)
            }
        }
        advertisements.onChange(initial: true) { @MainActor [weak self, weak device] _ in
            if let self, let device {
                handleAdvertisementChange(device)
            }
        }
        nearby.onChange { @MainActor [weak self, weak device] nearby in
            if let device, !nearby {
                // device discovery was cleared by SpeziBluetooth
                self?.handleDiscardedDevice(device)
            }
        }

        if let batteryPowered = device as? any BatteryPoweredDevice {
            batteryPowered.battery.$batteryLevel.onChange { @MainActor [weak self, weak device] value in
                if let self, let device, let pairedDevice = _newPairedDevices[device.id] {
                    pairedDevice.updateBattery(for: device, percentage: value)
                }
            }
        }

        logger.debug("Registered device \(device.label), \(device.id) with PairedDevices")
    }

    deinit {
        stateSubscriptionTask = nil
    }
}


extension PairedDevices: Module, EnvironmentAccessible, DefaultInitializable, @unchecked Sendable {}

// MARK: - Manual Discovery

@MainActor
extension PairedDevices {
    private func handleAdvertisementChange<Device: PairableDevice>(_ device: Device) {
        guard device.isInPairingMode, !isPaired(device), _discoveredDevices[device.id] == nil else {
            return
        }


        self.logger.info(
            "Detected nearby \(Device.self) accessory\(device.advertisementData.manufacturerData.map { " with manufacturer data \($0.debugDescription)" } ?? "")"
        )

        let discoveredDevice = DiscoveredDevice(device: device)
        _discoveredDevices[device.id] = discoveredDevice
    }

    private func handleDiscardedDevice<Device: PairableDevice>(_ device: Device) {
        let removed = _discoveredDevices.removeValue(forKey: device.id)
        if removed != nil {
            self.logger.debug("\(Device.self) \(device.label) was discarded from discovered devices.")
        }
    }

    /// Signal that a device is considered paired.
    ///
    /// You call this method from your device implementation on events that indicate that the device was successfully paired.
    /// - Note: This method does nothing if there is currently no ongoing pairing session for a device.
    /// - Parameter device: The device that can be considered paired and might have an ongoing pairing session.
    /// - Returns: Returns `true` if there was an ongoing pairing session and the device is now paired.
    @discardableResult
    public func signalDevicePaired(_ device: some PairableDevice) -> Bool {
        guard let discoveredDevice = _discoveredDevices[device.id] else {
            return false
        }

        return discoveredDevice.signalDevicePaired(device)
    }

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
    public func pair(with device: some PairableDevice, timeout: Duration = .seconds(15)) async throws {
        guard let discoveredDevice = _discoveredDevices[device.id] else {
            throw DevicePairingError.invalidState
        }

        guard discoveredDevice.ongoingPairing == nil else {
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
        
        // race timeout against the tasks below
        async let _ = await withTimeout(of: timeout) { @MainActor in
            discoveredDevice.clearPairingContinuationWithIntentionToResume()?.signalTimeout()
        }
        
        try await withThrowingDiscardingTaskGroup { group in
            // connect task
            group.addTask { @Sendable @SpeziBluetooth in
                do {
                    try await device.connect()
                } catch {
                    if error is CancellationError {
                        await MainActor.run {
                            discoveredDevice.clearPairingContinuationWithIntentionToResume()?.signalCancellation()
                        }
                    }
                    
                    throw error
                }
            }
            
            // pairing task
            group.addTask { @Sendable @MainActor in
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        discoveredDevice.assignContinuation(continuation)
                    }
                } onCancel: {
                    Task { @SpeziBluetooth [weak device] in
                        await MainActor.run {
                            discoveredDevice.clearPairingContinuationWithIntentionToResume()?.signalCancellation()
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
}

// MARK: - Device Pairing

@MainActor
extension PairedDevices {
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

        let pairedDevice = PairedDevice(info: deviceInfo, assigning: device)

        persistPairedDevice(pairedDevice)
    }

    private func persistPairedDevice(_ pairedDevice: PairedDevice) {
        _newPairedDevices[pairedDevice.info.id] = pairedDevice
        if let modelContainer {
            modelContainer.mainContext.insert(pairedDevice.info)
            do {
                try modelContainer.mainContext.save()
            } catch {
                logger.warning("Failed to persist PairedDevice \(pairedDevice.info.id) due to \(error).")
            }
        } else {
            logger.warning("PairedDevice \(pairedDevice.info.name), \(pairedDevice.info.id) could not be persisted due to missing ModelContainer!")
        }

        _discoveredDevices.removeValue(forKey: pairedDevice.info.id)

        self.logger.debug("Device \(pairedDevice.info.name) with id \(pairedDevice.info.id) is now paired!")

        if stateSubscriptionTask == nil {
            Task {
                await setupBluetoothStateSubscription()
            }
        }
    }

    /// Forget a paired device.
    /// - Parameter id: The Bluetooth peripheral identifier of a paired device.
    @available(*, deprecated, message: "Please use the async version of this method.")
    @_documentation(visibility: internal)
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
    public func forgetDevice(id: UUID) async throws {
        // TODO: device stays retrieved after forgetting!
        try await removeDevice(id: id) {
            if #available(iOS 18, *) {
                guard let accessorySetup,
                      let accessory = accessorySetup.accessories.first(where: { $0.bluetoothIdentifier == id }) else {
                    return false
                }

                // this will trigger a disconnect // TODO: does it?
                try await accessorySetup.removeAccessory(accessory)
                return true
            }
            return false
        }
    }

    private func removeDevice(id: UUID) async {
        await self.removeDevice(id: id) {
            false
        }
    }

    private func removeDevice(id: UUID, externalRemoval: () async throws -> Bool) async rethrows {
        let device = _newPairedDevices[id]
        device?.markForRemoval() // prevent the device from automatically reconnecting

        let externallyManaged: Bool
        do {
            externallyManaged = try await externalRemoval()
        } catch {
            device?.markForRemoval(false) // restore state again
            throw error
        }

        // just make sure to remove it from discovered devices
        let discoveredDevice = _discoveredDevices.removeValue(forKey: id)
        discoveredDevice?.clearPairingContinuationWithIntentionToResume()?.signalDisconnect()

        let removed = _newPairedDevices.removeValue(forKey: id)
        if let removed {
            modelContainer?.mainContext.delete(removed.info) // TODO: by uncommenting this, we can test import functionality?
            do {
                try modelContainer?.mainContext.save()
            } catch {
                logger.warning("Failed to persist device removal of \(removed.info.id): \(error)")
            }
            await removed.removeDevice(manualDisconnect: !externallyManaged)
        }

        if !_newPairedDevices.isEmpty {
            await self.cancelSubscription()
        }
    }
}


// MARK: - Paired Peripheral Management

@MainActor
extension PairedDevices {
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
            self._newPairedDevices = pairedDevices.reduce(into: [:]) { partialResult, deviceInfo in
                partialResult[deviceInfo.id] = PairedDevice(info: deviceInfo)
            }
            logger.debug("Initialized PairedDevices with \(self._newPairedDevices.count) paired devices!")
        } catch {
            logger.error("Failed to fetch paired device info from disk: \(error)")
        }
    }

    func refreshPairedDevices() throws {
        _newPairedDevices.removeAll()
        didLoadDevices = false

        if let modelContainer, modelContainer.mainContext.hasChanges {
            try modelContainer.mainContext.save()
        }

        fetchAllPairedInfos()
    }

    private func syncDeviceIcons() {
        guard let bluetooth else {
            return
        }

        let configuredDevices = bluetooth.configuredPairableDevices()

        for pairedDevice in _newPairedDevices.values {
            let deviceInfo = pairedDevice.info
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

    private func setupBluetoothStateSubscription() async {
        guard let bluetooth else {
            logger.warning("Tried to setup bluetooth state subscription while Bluetooth module wasn't loaded.")
            return
        }

        guard stateSubscriptionTask == nil else {
            logger.warning("Tried to setup bluetooth state subscription a second time!")
            return
        }

        assert(!_newPairedDevices.isEmpty, "Bluetooth State subscription doesn't need to be set up without any paired devices.")
        // TODO: log?

        let subscriptions = bluetooth.stateSubscription
        self.stateSubscriptionTask = Task.detached { [weak self] in
            for await nextState in subscriptions {
                guard let self else {
                    return
                }
                await self.handleBluetoothStateChanged(nextState) // TODO: we cannot wait forever!
            }
        }

        // If Bluetooth is currently turned off in control center or not authorized anymore, we would want to keep central allocated
        // such that we are notified about the bluetooth state changing.
        await bluetooth.powerOn()

        if case .poweredOn = bluetooth.state {
            await self.handleCentralPoweredOn()
        }
    }

    private func cancelSubscription() async {
        assert(_newPairedDevices.isEmpty, "Bluetooth State subscription was tried to be cancelled even though devices were still paired.")

        logger.debug("Cancelling state subscription and powering off bluetooth module.")
        stateSubscriptionTask = nil
        await bluetooth?.powerOff()
    }

    private func handleBluetoothStateChanged(_ state: BluetoothState) async {
        logger.debug("Bluetooth Module state is now \(state)")

        switch state {
        case .poweredOn:
            scheduledPowerOffTask = nil
            await handleCentralPoweredOn()
        case .poweredOff:
            scheduledPowerOffTask = Task {
                try? await Task.sleep(for: .seconds(1)) // TODO: is that long enough. What happens if that is a manual power off?
                guard !Task.isCancelled else {
                    return
                }

                await self.handleCentralPoweredOff()
            }
        case .unauthorized, .unsupported, .unknown:
            scheduledPowerOffTask = nil
            await handleCentralPoweredOff()
        }
    }

    private func handleCentralPoweredOn() async {
        guard let bluetooth else {
            return
        }

        guard case .poweredOn = bluetooth.state else {
            return
        }

        logger.debug("Powering on PairedDevices and retrieving device instances ...")

        // we just reuse the configured Bluetooth devices
        let configuredDevices = bluetooth.configuredPairableDevices()

        await withDiscardingTaskGroup { group in
            for pairedDevice in self._newPairedDevices.values {
                group.addTask { @Sendable @MainActor in
                    guard pairedDevice.peripheral == nil else {
                        return // already retrieved or otherwise initialized
                    }

                    guard let deviceType = configuredDevices[pairedDevice.info.deviceType] else {
                        self.logger.error("Unsupported device type \"\(pairedDevice.info.deviceType)\" for paired device \(pairedDevice.info.name).")
                        pairedDevice.info.notLocatable = true
                        return
                    }

                    await pairedDevice.retrieveDevice(for: deviceType, using: bluetooth)
                }
            }
        }
    }

    private func handleCentralPoweredOff() async {
        logger.debug("Powering off PairedDevices and cancelling connection attempts or ongoing connections ...")

        await withDiscardingTaskGroup { group in
            for device in _newPairedDevices.values {
                group.addTask {
                    await device.handlePowerOff()
                }
            }
        }
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
                    Task {
                        await handleSessionAvailable()
                    }
                case let .added(accessory):
                    Task {
                        await handleAddedAccessory(accessory)
                    }
                case let .changed(accessory):
                    updateAccessory(accessory)
                case let .removed(accessory):
                    Task {
                        await handleRemovedAccessory(accessory)
                    }
                }
            }

            self?.logger.debug("Accessory Change subscription completed!")
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

            guard _newPairedDevices[uuid] == nil else {
                continue // we are already paired
            }

            logger.debug("Found available accessory that hasn't been paired: \(accessory)")
            await handleAddedAccessory(accessory)
        }

        if !_newPairedDevices.isEmpty {
            await self.setupBluetoothStateSubscription()
        }
    }

    @MainActor
    func showAccessorySetupPicker() {
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
    private func handleAddedAccessory(_ accessory: ASAccessory) async {
        guard let bluetooth, let id = accessory.bluetoothIdentifier else {
            return
        }

        guard let deviceType = bluetooth.pairableDevice(matches: accessory.descriptor) else {
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

        let pairedDevice = PairedDevice(info: deviceInfo)

        // AccessorySetupKit switches of the central for a few milliseconds, so it might just be off right now.
        if case .poweredOn = bluetooth.state {
            await pairedDevice.retrieveDevice(for: deviceType, using: bluetooth)
        }

        // otherwise device retrieval is handled once bluetooth is powered on
        persistPairedDevice(pairedDevice)
    }

    @MainActor
    private func updateAccessory(_ accessory: ASAccessory) {
        guard let id = accessory.bluetoothIdentifier,
              let pairedDevice = _newPairedDevices[id] else {
            return // unknown device or not a bluetooth device
        }

        // allow to sync back name!
        pairedDevice.info.name = accessory.displayName
    }

    @MainActor
    private func handleRemovedAccessory(_ accessory: ASAccessory) async {
        guard let id = accessory.bluetoothIdentifier else {
            return
        }

        await removeDevice(id: id)
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

// swiftlint:disable:this file_length
