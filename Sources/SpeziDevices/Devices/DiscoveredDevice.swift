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


final class DiscoveredDevice: Sendable {
    private static nonisolated let logger = Logger(subsystem: "edu.stanford.spezi.SpeziDevices", category: "DiscoveredDevice")

    let device: any PairableDevice
    private nonisolated(unsafe) var ongoingPairing: PairingContinuation?
    private let nsLock = NSLock()

    var hasContinuationAssigned: Bool {
        nsLock.withLock {
            ongoingPairing != nil
        }
    }

    init(device: some PairableDevice) {
        self.device = device
    }

    private func consumeContinuation() -> PairingContinuation? {
        nsLock.withLock {
            let continuation = self.ongoingPairing
            self.ongoingPairing = nil
            return continuation
        }
    }

    func handleDeviceStateUpdated<Device: PairableDevice>(for device: Device, _ state: PeripheralState) {
        guard self.device === device else {
            return
        }

        switch state {
        case .disconnected:
            if let ongoingPairing = self.consumeContinuation() {
                Self.logger.debug("Device \(device.label), \(device.id) disconnected while pairing was ongoing")
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

        if let ongoingPairing = self.consumeContinuation() {
            Self.logger.debug("Device \(device.label), \(device.id) signaled it is fully paired.")
            ongoingPairing.signalPaired()
            return true
        }
        return false
    }

    func assignContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        nsLock.withLock {
            self.ongoingPairing?.signalCancellation()
            self.ongoingPairing = PairingContinuation(continuation)
        }
    }

    func clearPairingContinuationWithIntentionToResume() -> PairingContinuation? {
        self.consumeContinuation()
    }

    deinit {
        self.consumeContinuation()?.signalCancellation()
    }
}
