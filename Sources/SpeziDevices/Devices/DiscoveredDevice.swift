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
final class DiscoveredDevice: Sendable {
    private static nonisolated let logger = Logger(subsystem: "edu.stanford.spezi.SpeziDevices", category: "DiscoveredDevice")

    let device: any PairableDevice
    private(set) var ongoingPairing: PairingContinuation?

    init(device: some PairableDevice) {
        self.device = device
    }

    func handleDeviceStateUpdated<Device: PairableDevice>(for device: Device, _ state: PeripheralState) {
        guard self.device === device else {
            return
        }

        switch state {
        case .disconnected:
            if let ongoingPairing {
                Self.logger.debug("Device \(device.label), \(device.id) disconnected while pairing was ongoing")
                self.ongoingPairing = nil
                ongoingPairing.signalDisconnect()
            }
        default:
            break
        }
    }

    func signalDevicePaired(_ device: some PairableDevice) -> Bool {
        guard self.device === device else {
            return false
        }

        if let ongoingPairing {
            Self.logger.debug("Device \(device.label), \(device.id) signaled it is fully paired.")
            self.ongoingPairing = nil
            ongoingPairing.signalPaired()
            return true
        }
        return false
    }

    func assignContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        if let ongoingPairing {
            ongoingPairing.signalCancellation()
        }
        self.ongoingPairing = PairingContinuation(continuation)
    }

    func clearPairingContinuationWithIntentionToResume() -> PairingContinuation? {
        if let ongoingPairing {
            self.ongoingPairing = nil
            return ongoingPairing
        }
        return nil
    }

    deinit {
        ongoingPairing?.signalCancellation()
    }
}
