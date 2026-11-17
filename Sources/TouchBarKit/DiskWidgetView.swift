import AppKit

/// A single Touch Bar slot showing disk capacity: a small filled bar plus a percentage label.
/// The bar and label only redraw when the rounded percentage actually changes — PLAN.md §4.6 — so
/// a volume's byte-level free-space jitter (which changes every sample but rounds to the same
/// percent) doesn't force a redraw every tick.
public final class DiskWidgetView: NSView {
    private final class BarView: NSView {
        var fraction: Double = 0 {
            didSet { needsDisplay = true }
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.separatorColor.setFill()
            bounds.fill()
            let filledWidth = bounds.width * CGFloat(max(0, min(1, fraction)))
            NSColor.controlAccentColor.setFill()
            NSRect(x: 0, y: 0, width: filledWidth, height: bounds.height).fill()
        }
    }

    private let bar = BarView()
    private let label = NSTextField(labelWithString: "")
    private var gate = RedrawGate()

    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 110, height: 30))
        bar.frame = NSRect(x: 4, y: 11, width: 60, height: 6)
        bar.wantsLayer = true
        bar.layer?.cornerRadius = 3
        addSubview(bar)

        label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 0, width: 110, height: 10)
        addSubview(label)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize { NSSize(width: 110, height: 30) }

    public func update(totalBytes: UInt64, availableBytes: UInt64) {
        let text = DiskRowFormatter.percentString(totalBytes: totalBytes, availableBytes: availableBytes)
        guard gate.shouldRedraw(for: text) else { return }
        label.stringValue = text
        bar.fraction = DiskRowFormatter.usedFraction(totalBytes: totalBytes, availableBytes: availableBytes)
    }
}
