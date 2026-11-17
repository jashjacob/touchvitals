import Foundation

/// PLAN.md §6.8: "Route every number through the formatter layer so a comma-decimal locale never
/// produces '34,5' glued to a % from a different string." `String(format:)` without an explicit
/// `locale:` argument always uses a fixed decimal point — verified directly: `String(format:
/// "%.1f", 12.34)` prints `"12.3"` on this machine regardless of system locale, where `String(
/// format: "%.1f", locale: Locale(identifier: "de_DE"), 12.34)` correctly prints `"12,3"`. Every
/// numeric display in this app went through the first, unlocalized form until this existed — this
/// is the one place that omission gets fixed, rather than fixing it at each of the ~18 call sites
/// it was scattered across.
public enum LocaleNumberFormatter {
    /// `value` formatted with `precision` fraction digits, honouring the current locale's decimal
    /// separator. Callers append their own unit suffix (`"%"`, `"°C"`, `" Mbps"`) — those are
    /// symbols, not sentence text, so they don't need a formatter of their own.
    public static func string(_ value: Double, precision: Int) -> String {
        string(value, precision: precision, locale: .current)
    }

    /// The real implementation, with `locale` exposed rather than hardcoded to `.current` —
    /// otherwise nothing here is unit-testable without actually changing the test runner's system
    /// locale. `internal`, not `private`: `LocaleNumberFormatterTests` calls it directly with
    /// explicit locales to check the comma/point split this type exists to get right, without the
    /// public one-argument call site ever needing to know this exists.
    static func string(_ value: Double, precision: Int, locale: Locale) -> String {
        String(format: "%.\(precision)f", locale: locale, value)
    }
}
