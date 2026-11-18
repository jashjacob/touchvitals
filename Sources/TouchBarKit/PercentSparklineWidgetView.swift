import AppKit
import MetricsCore

/// An icon chip (color-coded by CapacityFormatter.severity) plus a mini history sparkline — the
/// shared layout for CPU and Memory widgets, which differ only in their icon/prefix and how their
/// percent is computed upstream (CPUUsage.overallPercent is already a percentage; memory's comes
/// from CapacityFormatter.usedFraction on bytes). AppKit drawing is untestable by design — the
/// percent/severity math it calls is tested.
public final class PercentSparklineWidgetView: NSView {
    private let chip: IconValueChip
    private let sparkline: SparklineView?
    private var gate = RedrawGate()
    private var history = RingBuffer<Double>(capacity: 30)

    public init(
        symbolName: String,
        showSparkline: Bool = true,
        chipWidth: CGFloat = 62,
        sparklineWidth: CGFloat = 50,
        height: CGFloat = 30
    ) {
        chip = IconValueChip(symbolName: symbolName, width: chipWidth)
        let totalWidth = showSparkline ? chipWidth + sparklineWidth : chipWidth
        sparkline = showSparkline ? SparklineView(width: sparklineWidth, height: height) : nil
        super.init(frame: NSRect(x: 0, y: 0, width: totalWidth, height: height))

        chip.frame.origin = NSPoint(x: 0, y: (height - chip.frame.height) / 2)
        addSubview(chip)

        if let sparkline {
            sparkline.frame.origin = NSPoint(x: chipWidth, y: 0)
            addSubview(sparkline)
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize { frame.size }

    /// `percent` is 0...100, matching CPUUsage.overallPercent's own unit directly.
    public func update(percent: Double) {
        let fraction = max(0, min(1, percent / 100))
        let text = CapacityFormatter.percentString(fraction: fraction)
        if gate.shouldRedraw(for: text) {
            chip.update(text: text, tint: color(for: CapacityFormatter.severity(usedFraction: fraction)))
        }
        history.append(percent)
        // Fixed 0...100% scale, not SparklineFormatter's auto-scaled min/max — CPU and memory are
        // naturally bounded percentages, so the line's height should directly match the percent
        // chip beside it (0% = bottom, 100% = top). Auto-scaling would make a 10-30% wobble fill
        // the same height as an 80-100% one, with no way to tell which from the shape alone.
        sparkline?.update(points: history.inChronologicalOrder().map { max(0, min(1, $0 / 100)) })
    }

    private func color(for severity: CapacityFormatter.Severity) -> NSColor {
        switch severity {
        case .normal: .controlAccentColor
        case .warning: .systemOrange
        case .critical: .systemRed
        }
    }
}
