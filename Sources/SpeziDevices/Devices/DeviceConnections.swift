//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import OSLog
import SpeziBluetooth
import SpeziFoundation

/// Manages and handles ongoing device connection attempts.
struct DeviceConnections: Sendable {
    /// Retry configuration for a single connection.
    ///
    /// Implements a exponential backoff.
    struct RetryConfiguration {
        /// The initial backoff duration.
        var initialBackoff: Duration
        /// The maximum backoff duration.
        var maxBackoff: Duration
        /// The minimum period, if in which no error occurs, the error counter is reset.
        var minimumQuietPeriod: Duration

        /// The minimum time to wait after a regular disconnect, to reconnect to the device.
        var reconnectBackoff: Duration

        init(
            initialBackoff: Duration = .seconds(0.5),
            maxBackoff: Duration = .seconds(30),
            minimumQuietPeriod: Duration = .seconds(60),
            reconnectBackoff: Duration = .seconds(3)
        ) {
            self.initialBackoff = initialBackoff
            self.maxBackoff = maxBackoff
            self.minimumQuietPeriod = minimumQuietPeriod
            self.reconnectBackoff = reconnectBackoff
        }
    }

    private enum Input {
        case connect(_ device: PairedDevice, _ bluetooth: Bluetooth)
        case cancel(_ device: PairedDevice)
        case clearStaleState(deviceId: UUID, id: UUID)
    }

    private static let logger = Logger(subsystem: "edu.stanford.spezi.spezidevices", category: "\(Self.self)")

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
