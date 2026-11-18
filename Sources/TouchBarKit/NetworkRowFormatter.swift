import MetricsCore

/// The single-slot Touch Bar network row: compact down/up arrows plus rate text.
public enum NetworkRowFormatter {
    public static func downText(downBytesPerSec: Double) -> String {
        "↓ \(ByteRateFormatter.format(bytesPerSecond: downBytesPerSec))"
    }

    public static func upText(upBytesPerSec: Double) -> String {
        "↑ \(ByteRateFormatter.format(bytesPerSecond: upBytesPerSec))"
    }

    public static func format(downBytesPerSec: Double, upBytesPerSec: Double) -> String {
        "\(downText(downBytesPerSec: downBytesPerSec))  \(upText(upBytesPerSec: upBytesPerSec))"
    }
}
