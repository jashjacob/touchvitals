import os

/// PLAN.md §4.12/item 1.9: `OSSignposter` on every sample and render, so a real Instruments trace
/// can show exactly how long each module's `sample()` took, how the samplers interleave on the
/// scheduler's single timer, and how long each widget's `draw(_:)` takes — without adding a
/// single `print` to either hot path. `os_signpost` intervals cost nothing when no one is
/// recording (Instruments, or `log stream`) and are visible without one:
/// `log stream --predicate 'subsystem == "com.vitals.app"'`.
///
/// Two separate `OSSignposter`s (`sampler`/`render`), not one shared instance: sampling and
/// drawing interleave constantly (a sample arriving is what triggers the next draw), and a single
/// Instruments lane mixing both would make it hard to see which is which at a glance.
public enum Signposts {
    public static let sampler = OSSignposter(subsystem: "com.vitals.app", category: "Sampler")
    public static let render = OSSignposter(subsystem: "com.vitals.app", category: "Render")
}
