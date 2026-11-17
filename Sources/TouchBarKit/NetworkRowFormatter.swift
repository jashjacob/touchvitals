import MetricsCore

/// The single-slot Touch Bar network row: compact down/up arrows plus rate text.
public enum NetworkRowFormatter {
    public static func format(downBytesPerSec: Double, upBytesPerSec: Double) -> String {
        let down = ByteRateFormatter.format(bytesPerSecond: downBytesPerSec)
        let up = ByteRateFormatter.format(bytesPerSecond: upBytesPerSec)
        return "↓ \(down)  ↑ \(up)"
    }
}
