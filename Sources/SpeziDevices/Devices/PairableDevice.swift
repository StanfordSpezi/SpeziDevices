//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SpeziFoundation


/// A Bluetooth device that is pairable.
public protocol PairableDevice: GenericDevice {
    /// Persistent identifier for the device type.
    ///
    /// This is used to associate pairing information with the implementing device. By default, the type name is used.
    static var deviceTypeIdentifier: String { get }

    /// Indicate that the device is nearby.
    ///
    /// Use the [`DeviceState`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/devicestate) property wrapper to
    /// declare this property.
    /// ```swift
    /// @DeviceState(\.nearby) var nearby
    /// ```
    var nearby: Bool { get }

    /// Storage for pairing continuation.
    var pairing: PairingContinuation { get }
    // TODO: use SPI for access?

    /// Connect action.
    ///
    /// Use the [`DeviceAction`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/deviceaction) property wrapper to
    /// declare this property.
    /// ```swift
    /// @DeviceAction(\.connect) var connect
    /// ```
    var connect: BluetoothConnectAction { get }
    /// Disconnect action.
    ///
    /// Use the [`DeviceAction`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/deviceaction) property wrapper to
    /// declare this property.
    /// ```swift
    /// @DeviceAction(\.disconnect) var disconnect
    /// ```
    var disconnect: BluetoothDisconnectAction { get }

    /// Determines if the device is currently able to get paired.
    ///
    /// This might be a value that is reported by the device for example through the manufacturer data in the Bluetooth advertisement.
    var isInPairingMode: Bool { get }

    /// Start pairing procedure with the device.
    ///
    /// This method pairs with a currently advertising Bluetooth device.
    /// - Note: The ``isInPairingMode`` property determines if the device is currently pairable.
    ///
    /// This method is implemented by default.
    /// - Important: In order to support the default implementation, you **must** interact with the ``PairingContinuation`` accordingly.
    ///     Particularly, you must call the ``PairingContinuation/signalPaired()`` and ``PairingContinuation/signalDisconnect()``
    ///     methods when appropriate.
    /// - Throws: Throws a ``DevicePairingError`` if not successful.
    func pair() async throws // TODO: make a pair(with:) (passing the DevicePairings?) so the PairedDevicesx module manages the continuations?
}


extension PairableDevice {
    /// Default persistent identifier for the device type.
    ///
    /// Defaults to the Swift type name.
    public static var deviceTypeIdentifier: String {
        "\(Self.self)"
    }
}


extension PairableDevice {
    /// Default pairing implementation.
    ///
    /// The default implementation verifies that the device ``isInPairingMode``, is currently disconnected and ``nearby``.
    /// It automatically connects to the device to start pairing. Pairing has a 15 second timeout by default. Pairing is considered successful once
    /// ``PairingContinuation/signalPaired()`` gets called. It is considered unsuccessful once ``PairingContinuation/signalDisconnect`` is called.
    /// - Throws: Throws a ``DevicePairingError`` if not successful.
    public func pair() async throws { // TODO: just move the whole method to the PairedDevices thing!
        guard isInPairingMode else {
            throw DevicePairingError.notInPairingMode
        }

        guard case .disconnected = state else {
            throw DevicePairingError.invalidState
        }

        guard nearby else {
            throw DevicePairingError.invalidState
        }


        try await pairing.withPairingSession {
            await connect()

            async let _ = withTimeout(of: .seconds(15)) {
                pairing.signalTimeout()
            }

            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    pairing.assign(continuation: continuation)
                }
            } onCancel: {
                Task { @MainActor in
                    pairing.signalCancellation()
                    await disconnect()
                }
            }
        }
    }
}
