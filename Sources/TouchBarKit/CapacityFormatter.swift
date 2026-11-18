/// Generic "used / total" capacity math shared by disk, CPU, and memory widgets: a 0...1 fraction,
/// a rounded percentage, and a severity level for color-coding.
public enum CapacityFormatter {
    public enum Severity: Equatable {
        case normal
        case warning
        case critical
    }

    /// Thresholds match common disk-full warning conventions: comfortable below 80%, worth
    /// noticing from 80%, urgent from 95%. Boundaries are inclusive on the higher severity.
    public static func severity(usedFraction: Double) -> Severity {
        if usedFraction >= 0.95 { return .critical }
        if usedFraction >= 0.8 { return .warning }
        return .normal
    }

    /// 0...1 fraction of `totalBytes` currently used. A zero-capacity volume (or bad data where
    /// `availableBytes` exceeds `totalBytes`) clamps to 0 rather than dividing by zero or going
    /// negative.
    public static func usedFraction(totalBytes: UInt64, availableBytes: UInt64) -> Double {
        guard totalBytes > 0, availableBytes <= totalBytes else { return 0 }
        let used = Double(totalBytes - availableBytes)
        return used / Double(totalBytes)
    }

    public static func percentString(totalBytes: UInt64, availableBytes: UInt64) -> String {
        percentString(fraction: usedFraction(totalBytes: totalBytes, availableBytes: availableBytes))
    }

    /// For callers (CPU) that already have a 0...1 fraction and no total/available bytes to derive
    /// it from. Clamps out-of-range input rather than printing a negative or over-100 percentage.
    public static func percentString(fraction: Double) -> String {
        let percent = (max(0, min(1, fraction)) * 100).rounded()
        return "\(Int(percent))%"
    }
}
