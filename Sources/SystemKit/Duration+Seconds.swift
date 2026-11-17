extension Duration {
    /// This duration in seconds as a `Double`, floored at a millisecond so it is always safe to
    /// divide a byte delta by — for the rate samplers, whose `now - previous` gap can in principle
    /// be zero.
    public var rateWindowSeconds: Double {
        max(0.001, Double(components.seconds) + Double(components.attoseconds) / 1e18)
    }
}
