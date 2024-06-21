//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SpeziFoundation

// TODO: docs all the way!

public protocol PairableDevice: GenericDevice {
    /// Persistent identifier for the device type.
    ///
    /// This is used to associate pairing information with the implementing device. By default, the type name is used.
    static var deviceTypeIdentifier: String { get }

    /// Storage for pairing continuation.
    @MainActor var _pairingContinuation: CheckedContinuation<Void, Error>? { get set } // swiftlint:disable:this identifier_name
    // TODO: do not synchronize via MainActor??
    // TODO: use SPI instead of underscore when moving to SpeziDevices? => avoid swiftlint warning for implementors

    var connect: BluetoothConnectAction { get }
    var disconnect: BluetoothDisconnectAction { get }

    var isInPairingMode: Bool { get }

    /// Pair Omron Health Device.
    ///
    /// This method pairs a currently advertising Omron Health Device.
    /// - Note: Make sure that the device is in pairing mode (holding down the Bluetooth button for 3 seconds) and disconnected.
    ///
    /// This method is implemented by default. In order to support the default implementation, you MUST call `handleDeviceInteraction()`
    /// on notifications or indications received from the device. This indicates that pairing was successful.
    /// Further, your implementation MUST call `handleDeviceDisconnected()` if the device disconnects to handle pairing issues.
    @MainActor // TODO: actor isolation?
    func pair() async throws
}


extension PairableDevice {
    public static var deviceTypeIdentifier: String {
        "\(Self.self)"
    }
}


extension PairableDevice {
    @MainActor
    public func pair() async throws {
        guard _pairingContinuation == nil else {
            throw DevicePairingError.busy
        }

        guard isInPairingMode else {
            throw DevicePairingError.notInPairingMode
        }

        guard case .disconnected = state else {
            throw DevicePairingError.invalidState
        }

        guard !discarded else {
            throw DevicePairingError.invalidState
        }

        await connect()

        async let _ = withTimeout(of: .seconds(15)) { @MainActor in
            resumePairingContinuation(with: .failure(TimeoutError()))
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self._pairingContinuation = continuation
            }
        } onCancel: {
            Task { @MainActor in
                resumePairingContinuation(with: .failure(CancellationError()))
                await disconnect()
            }
        }
        // TODO: Self.logger.debug("Device \(self.label) with id \(self.id) is now paired") // TODO: Move logger!
    }

    @MainActor
    public func handleDeviceInteraction() {
        // any kind of messages received from the the device is interpreted as successful pairing.
        resumePairingContinuation(with: .success(()))
    }

    @MainActor
    public func handleDeviceDisconnected() {
        resumePairingContinuation(with: .failure(DevicePairingError.deviceDisconnected))
    }

    @MainActor
    private func resumePairingContinuation(with result: Result<Void, Error>) {
        if let pairingContinuation = _pairingContinuation {
            pairingContinuation.resume(with: result)
            self._pairingContinuation = nil
        }
    }
}
