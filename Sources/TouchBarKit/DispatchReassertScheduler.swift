import Dispatch
import Foundation

/// Real `ReassertScheduling` backed by a single `DispatchWorkItem` — cancelling the previous one
/// before scheduling a new one is the actual debounce mechanism; `ReassertController` just decides
/// when to call this.
public final class DispatchReassertScheduler: ReassertScheduling {
    private var pendingWorkItem: DispatchWorkItem?
    private let queue: DispatchQueue

    public init(queue: DispatchQueue = .main) {
        self.queue = queue
    }

    public func scheduleReassert(after delay: TimeInterval, _ action: @escaping () -> Void) {
        let item = DispatchWorkItem(block: action)
        pendingWorkItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    public func cancelPendingReassert() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }
}
