/// Fixed-capacity circular buffer for time-series history — PLAN.md §4.7: append/overwrite in
/// place, never `append`+`removeFirst` on an `Array` (that's an O(n) shift on every sample).
public struct RingBuffer<Element>: Sendable where Element: Sendable {
    private var storage: [Element?]
    private var head = 0
    private(set) public var count = 0

    public init(capacity: Int) {
        storage = Array(repeating: nil, count: max(1, capacity))
    }


    public mutating func append(_ element: Element) {
        storage[head] = element
        head = (head + 1) % storage.count
        count = Swift.min(count + 1, storage.count)
    }

    /// Oldest-to-newest snapshot. O(capacity); call on render, not on every sample.
    public func inChronologicalOrder() -> [Element] {
        guard count > 0 else { return [] }
        let start = count < storage.count ? 0 : head
        return (0..<count).compactMap { storage[(start + $0) % storage.count] }
    }
}
