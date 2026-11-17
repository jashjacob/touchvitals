import Foundation

/// Stderr-only logger — PrivateTouchBar.swift calls Log.line(...) and logs instead of crashing
/// when a private symbol is missing.
public enum Log {
    public static func line(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        FileHandle.standardError.write(Data("\(stamp) \(message)\n".utf8))
    }
}
