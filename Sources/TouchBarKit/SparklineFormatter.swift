/// Pure min-max normalization for the mini history sparkline — no AppKit, so it's unit-testable
/// independent of SparklineView's actual drawing (which isn't, by design).
public enum SparklineFormatter {
    /// Maps each value into 0...1 by the input's own min/max, preserving order. An empty input
    /// yields no points; a single value, or all-equal values, yields a flat 0.5 line rather than
    /// dividing by zero.
    public static func normalizedPoints(_ values: [Double]) -> [Double] {
        guard let min = values.min(), let max = values.max() else { return [] }
        let range = max - min
        guard range > 0 else { return values.map { _ in 0.5 } }
        return values.map { ($0 - min) / range }
    }
}
