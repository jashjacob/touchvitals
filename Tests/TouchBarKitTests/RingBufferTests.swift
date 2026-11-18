import Testing
import MetricsCore

@Suite("RingBuffer")
struct RingBufferTests {
    @Test("An empty buffer reports zero count and an empty chronological order")
    func emptyBufferIsEmpty() {
        let buffer = RingBuffer<Int>(capacity: 3)
        #expect(buffer.count == 0)
        #expect(buffer.inChronologicalOrder() == [])
    }

    @Test("Appending fewer elements than capacity returns them in insertion order")
    func belowCapacityKeepsInsertionOrder() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(1)
        buffer.append(2)
        #expect(buffer.count == 2)
        #expect(buffer.inChronologicalOrder() == [1, 2])
    }

    @Test("Appending exactly capacity elements keeps all of them in order")
    func atCapacityKeepsAllElements() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        #expect(buffer.count == 3)
        #expect(buffer.inChronologicalOrder() == [1, 2, 3])
    }

    @Test("Appending past capacity overwrites the oldest elements first, oldest-to-newest order preserved")
    func pastCapacityEvictsOldest() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        buffer.append(4)
        buffer.append(5)
        #expect(buffer.count == 3)
        #expect(buffer.inChronologicalOrder() == [3, 4, 5])
    }

    @Test("A zero or negative capacity is treated as 1 — the buffer always holds at least the newest element")
    func nonPositiveCapacityClampsToOne() {
        var buffer = RingBuffer<Int>(capacity: 0)
        buffer.append(1)
        buffer.append(2)
        #expect(buffer.count == 1)
        #expect(buffer.inChronologicalOrder() == [2])
    }
}
