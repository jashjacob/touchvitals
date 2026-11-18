import Testing
@testable import TouchBarKit

@Suite("CapacityFormatter")
struct CapacityFormatterTests {
    @Test("A fully-free volume has 0 used fraction and shows 0%")
    func emptyVolume() {
        #expect(CapacityFormatter.usedFraction(totalBytes: 1000, availableBytes: 1000) == 0)
        #expect(CapacityFormatter.percentString(totalBytes: 1000, availableBytes: 1000) == "0%")
    }

    @Test("A completely full volume has 1.0 used fraction and shows 100%")
    func fullVolume() {
        #expect(CapacityFormatter.usedFraction(totalBytes: 1000, availableBytes: 0) == 1)
        #expect(CapacityFormatter.percentString(totalBytes: 1000, availableBytes: 0) == "100%")
    }

    @Test("A partially-used volume computes the exact fraction and rounds the percentage")
    func partialVolume() {
        #expect(CapacityFormatter.usedFraction(totalBytes: 1000, availableBytes: 650) == 0.35)
        #expect(CapacityFormatter.percentString(totalBytes: 1000, availableBytes: 650) == "35%")
        #expect(CapacityFormatter.percentString(totalBytes: 1000, availableBytes: 667) == "33%")
    }

    @Test("A zero-capacity volume never divides by zero")
    func zeroCapacity() {
        #expect(CapacityFormatter.usedFraction(totalBytes: 0, availableBytes: 0) == 0)
        #expect(CapacityFormatter.percentString(totalBytes: 0, availableBytes: 0) == "0%")
    }

    @Test("Bad data where available exceeds total clamps to a 0 fraction instead of going negative")
    func clampsAgainstBadData() {
        #expect(CapacityFormatter.usedFraction(totalBytes: 1000, availableBytes: 1200) == 0)
    }

    @Test("Severity is normal below 80% used")
    func severityNormalBelowWarningThreshold() {
        #expect(CapacityFormatter.severity(usedFraction: 0) == .normal)
        #expect(CapacityFormatter.severity(usedFraction: 0.79) == .normal)
    }

    @Test("Severity becomes warning at 80% used, up to just below 95%")
    func severityWarningBetweenThresholds() {
        #expect(CapacityFormatter.severity(usedFraction: 0.8) == .warning)
        #expect(CapacityFormatter.severity(usedFraction: 0.94) == .warning)
    }

    @Test("Severity becomes critical at 95% used and stays critical through 100%")
    func severityCriticalAtAndAboveThreshold() {
        #expect(CapacityFormatter.severity(usedFraction: 0.95) == .critical)
        #expect(CapacityFormatter.severity(usedFraction: 1.0) == .critical)
    }

    @Test("percentString(fraction:) rounds a plain 0...1 fraction the same way the bytes-based overload does — for CPU/memory callers with no total/available bytes to pass")
    func percentStringFromPlainFraction() {
        #expect(CapacityFormatter.percentString(fraction: 0) == "0%")
        #expect(CapacityFormatter.percentString(fraction: 1) == "100%")
        #expect(CapacityFormatter.percentString(fraction: 0.421) == "42%")
    }

    @Test("percentString(fraction:) clamps out-of-range input instead of printing a nonsense percentage")
    func percentStringFromFractionClampsOutOfRange() {
        #expect(CapacityFormatter.percentString(fraction: -0.5) == "0%")
        #expect(CapacityFormatter.percentString(fraction: 1.5) == "100%")
    }
}
