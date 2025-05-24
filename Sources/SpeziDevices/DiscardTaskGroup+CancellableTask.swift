/// A handle to a child task that can be cancelled
public struct CancelableTaskHandle: Sendable {
    @usableFromInline private(set) var continuation: AsyncStream<Void>.Continuation

    @inlinable
    init(continuation: AsyncStream<Void>.Continuation) {
        self.continuation = continuation
    }

    /// Cancel the child task.
    @inlinable
    public func cancel() {
        self.continuation.finish()
    }
}


extension DiscardingTaskGroup { // TODO: replace by SpeziFoundation one
    @usableFromInline
    enum _CancelableState: Sendable {
        case finished
        case canceled
    }
    
    /// Add a child task that is cancellable through the handle returned.
    /// - Parameter operation: The child task to perform.
    /// - Returns: Returns a task handle that can be used to cancel the task.
    @inlinable
    public mutating func addCancelableTask(_ operation: @escaping @Sendable () async -> Void) -> CancelableTaskHandle {
        let signal = AsyncStream<Void>.makeStream()

        self.addTask {
            await withTaskGroup(of: _CancelableState.self) { group in
                group.addTask {
                    for await _ in signal.stream {}
                    return .canceled
                }

                group.addTask {
                    await operation()
                    return .finished
                }

                guard let first = await group.next() else {
                    fatalError("Child Task inconsistency.") // we spawned two tasks, something must be returned!
                }

                group.cancelAll() // either send the cancellation to the `operation` or make sure `stream` returns nil

                guard let second = await group.next() else {
                    fatalError("Child Task inconsistency.")
                }

                switch (first, second) {
                case (.finished, .canceled), (.canceled, .finished):
                    break
                default:
                    fatalError("Inconsistent state returned from child tasks: \(first), \(second).")
                }
            }
        }

        return CancelableTaskHandle(continuation: signal.continuation)
    }
}
