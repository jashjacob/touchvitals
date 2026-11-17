import Testing
@testable import TouchBarKit

@Suite("DiskRowFormatter")
struct DiskRowFormatterTests {
    @Test("A fully-free volume has 0 used fraction and shows 0%")
    func emptyVolume() {
        #expect(DiskRowFormatter.usedFraction(totalBytes: 1000, availableBytes: 1000) == 0)
        #expect(DiskRowFormatter.percentString(totalBytes: 1000, availableBytes: 1000) == "0%")
    }

    @Test("A completely full volume has 1.0 used fraction and shows 100%")
    func fullVolume() {
        #expect(DiskRowFormatter.usedFraction(totalBytes: 1000, availableBytes: 0) == 1)
        #expect(DiskRowFormatter.percentString(totalBytes: 1000, availableBytes: 0) == "100%")
    }

    @Test("A partially-used volume computes the exact fraction and rounds the percentage")
    func partialVolume() {
        #expect(DiskRowFormatter.usedFraction(totalBytes: 1000, availableBytes: 650) == 0.35)
        #expect(DiskRowFormatter.percentString(totalBytes: 1000, availableBytes: 650) == "35%")
        #expect(DiskRowFormatter.percentString(totalBytes: 1000, availableBytes: 667) == "33%")
    }

    @Test("A zero-capacity volume never divides by zero")
    func zeroCapacity() {
        #expect(DiskRowFormatter.usedFraction(totalBytes: 0, availableBytes: 0) == 0)
        #expect(DiskRowFormatter.percentString(totalBytes: 0, availableBytes: 0) == "0%")
    }

    @Test("Bad data where available exceeds total clamps to a 0 fraction instead of going negative")
    func clampsAgainstBadData() {
        #expect(DiskRowFormatter.usedFraction(totalBytes: 1000, availableBytes: 1200) == 0)
    }
}
