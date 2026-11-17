/// The single-slot Touch Bar disk row: a capacity-bar fraction plus a rounded percentage.
public enum DiskRowFormatter {
    /// 0...1 fraction of `totalBytes` currently used. A zero-capacity volume (or bad data where
    /// `availableBytes` exceeds `totalBytes`) clamps to 0 rather than dividing by zero or going
    /// negative.
    public static func usedFraction(totalBytes: UInt64, availableBytes: UInt64) -> Double {
        guard totalBytes > 0, availableBytes <= totalBytes else { return 0 }
        let used = Double(totalBytes - availableBytes)
        return used / Double(totalBytes)
    }

    public static func percentString(totalBytes: UInt64, availableBytes: UInt64) -> String {
        let percent = (usedFraction(totalBytes: totalBytes, availableBytes: availableBytes) * 100).rounded()
        return "\(Int(percent))%"
    }
}
