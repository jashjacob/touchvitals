import AppKit

/// A single Touch Bar slot showing disk capacity as an icon chip (color-coded by
/// CapacityFormatter.severity), matching every other widget's chip styling instead of a standalone
/// capacity bar. Only redraws when the rounded percentage actually changes — PLAN.md §4.6 — so a
/// volume's byte-level free-space jitter (which changes every sample but rounds to the same
/// percent) doesn't force a redraw every tick.
public final class DiskWidgetView: NSView {
    private let chip = IconValueChip(symbolName: "internaldrive", width: 70)
    private var gate = RedrawGate()

    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 70, height: 30))
        chip.frame.origin = NSPoint(x: 0, y: (30 - chip.frame.height) / 2)
        addSubview(chip)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize { NSSize(width: 70, height: 30) }

    public func update(totalBytes: UInt64, availableBytes: UInt64) {
        let text = CapacityFormatter.percentString(totalBytes: totalBytes, availableBytes: availableBytes)
        guard gate.shouldRedraw(for: text) else { return }
        let fraction = CapacityFormatter.usedFraction(totalBytes: totalBytes, availableBytes: availableBytes)
        let tint: NSColor
        switch CapacityFormatter.severity(usedFraction: fraction) {
        case .normal: tint = .controlAccentColor
        case .warning: tint = .systemOrange
        case .critical: tint = .systemRed
        }
        chip.update(text: text, tint: tint)
    }
}
