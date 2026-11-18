import Foundation

/// Whether the sparkline history graphs are shown, persisted across launches. Read once at launch
/// when ExpandedBarView builds its layout — toggling it from the menu bar takes effect on the next
/// launch rather than live, which keeps the Touch Bar's width (and its layout math) fixed for the
/// life of a single run instead of needing to handle a mid-session relayout.
public enum GraphsPreference {
    private static let key = "com.jashjacob.TouchVitals.showGraphs"

    /// Defaults to off: three unlabeled sparklines sitting between icon chips proved hard to
    /// attribute at a glance regardless of color/scale tuning — the clean icon+percent chips are
    /// the default, graphs are an opt-in extra from the menu bar.
    public static var isEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: key) != nil else { return false }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
