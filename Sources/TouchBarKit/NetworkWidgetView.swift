import AppKit

/// A single Touch Bar slot showing network down/up rate. Only touches AppKit (sets
/// `stringValue`) when `RedrawGate` says the formatted text actually changed — PLAN.md §4.6.
public final class NetworkWidgetView: NSView {
    private let label = NSTextField(labelWithString: "")
    private var gate = RedrawGate()

    public init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 170, height: 30))
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.alignment = .center
        label.frame = bounds
        label.autoresizingMask = [.width, .height]
        addSubview(label)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize { NSSize(width: 170, height: 30) }

    public func update(downBytesPerSec: Double, upBytesPerSec: Double) {
        let text = NetworkRowFormatter.format(downBytesPerSec: downBytesPerSec, upBytesPerSec: upBytesPerSec)
        guard gate.shouldRedraw(for: text) else { return }
        label.stringValue = text
    }
}
