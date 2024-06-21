//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation


/// Stores pairing state information.
public final class PairingContinuation {
    private let lock = NSLock()

    private var isInSession = false
    private var pairingContinuation: CheckedContinuation<Void, Error>?

    public init() {}

    func pairingSession<T>(_ action: () async throws -> T) async throws -> T {
        try lock.withLock {
            guard !isInSession else {
                throw DevicePairingError.busy
            }

            assert(pairingContinuation == nil, "Started pairing session, but continuation was not nil.")
            isInSession = true
        }

        defer {
            lock.withLock{
                isInSession = false
            }
        }

        return try await action()
    }

    func assign(continuation: CheckedContinuation<Void, Error>) {
        if lock.try() {
            lock.unlock()
            preconditionFailure("Tried to assign continuation outside of calling pairingSession(_:)")
        }
        self.pairingContinuation = continuation
    }

    private func resumePairingContinuation(with result: Result<Void, Error>) {
        lock.withLock {
            if let pairingContinuation {
                pairingContinuation.resume(with: result)
                self.pairingContinuation = nil
            }
        }
    }

    func signalTimeout() {
        resumePairingContinuation(with: .failure(TimeoutError()))
    }

    func signalCancellation() {
        resumePairingContinuation(with: .failure(CancellationError()))
    }

    /// Signal that the device was successfully paired.
    ///
    /// This method should always be called if the condition for a successful pairing happened. It may be called even if there isn't currently a ongoing pairing.
    public func signalPaired() {
        resumePairingContinuation(with: .success(()))
    }

    /// Signal that the device disconnected.
    ///
    /// This method should always be called if the condition for a successful pairing happened. It may be called even if there isn't currently a ongoing pairing.
    public func signalDisconnect() {
        resumePairingContinuation(with: .failure(DevicePairingError.deviceDisconnected))
    }
}


extension PairingContinuation: @unchecked Sendable {}
