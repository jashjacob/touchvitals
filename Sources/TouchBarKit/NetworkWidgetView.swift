import AppKit
import MetricsCore

/// A single Touch Bar slot showing network down/up rate as two tinted icon chips — down (incoming,
/// blue, arrow.down) and up (outgoing, orange, arrow.up) — instead of plain colored text, matching
/// IconValueChip's shared visual language across every widget.
public final class NetworkWidgetView: NSView {
    private let downChip = IconValueChip(symbolName: "arrow.down", width: 78)
    private let upChip = IconValueChip(symbolName: "arrow.up", width: 78)
    private var downGate = RedrawGate()
    private var upGate = RedrawGate()

    public override var intrinsicContentSize: NSSize { NSSize(width: 162, height: 30) }

    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 162, height: 30))
        let chipY = (30 - downChip.frame.height) / 2

        downChip.frame.origin = NSPoint(x: 0, y: chipY)
        addSubview(downChip)

        upChip.frame.origin = NSPoint(x: downChip.frame.width + 6, y: chipY)
        addSubview(upChip)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(downBytesPerSec: Double, upBytesPerSec: Double) {
        let downText = ByteRateFormatter.format(bytesPerSecond: downBytesPerSec)
        if downGate.shouldRedraw(for: downText) {
            downChip.update(text: downText, tint: .systemBlue)
        }
        let upText = ByteRateFormatter.format(bytesPerSecond: upBytesPerSec)
        if upGate.shouldRedraw(for: upText) {
            upChip.update(text: upText, tint: .systemOrange)
        }
    }
}
