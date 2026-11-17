import Foundation

/// Pure formatting — PLAN.md §4.6, "the widget draw path" wants a pure draw function fed by
/// pure formatting, so it can be unit-tested without a live NSStatusItem.
public enum ByteRateFormatter {
    private static let units = ["B", "KB", "MB", "GB"]

    public static func format(bytesPerSecond: Double) -> String {
        var value = bytesPerSecond
        var unitIndex = 0
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        let precision = value < 10 && unitIndex > 0 ? 1 : 0
        return "\(LocaleNumberFormatter.string(value, precision: precision)) \(units[unitIndex])/s"
    }
}
