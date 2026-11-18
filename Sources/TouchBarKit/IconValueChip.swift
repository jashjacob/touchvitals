import AppKit

/// A small rounded capsule containing an SF Symbol icon and a value label, tinted by whatever
/// accent color `update(text:tint:)` is given. The shared visual language for every Touch Bar
/// metric widget (network, CPU, memory, disk) instead of each one styling itself differently.
/// AppKit drawing, untestable by design — same tier as SparklineView.
public final class IconValueChip: NSView {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    public init(symbolName: String, width: CGFloat, height: CGFloat = 22) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        wantsLayer = true
        layer?.cornerRadius = height / 2
        layer?.masksToBounds = true

        let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        icon?.isTemplate = true
        iconView.image = icon
        iconView.contentTintColor = .white
        iconView.imageScaling = .scaleProportionallyDown
        iconView.frame = NSRect(x: 6, y: (height - 13) / 2, width: 13, height: 13)
        addSubview(iconView)

        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.alignment = .left
        label.lineBreakMode = .byClipping
        label.frame = NSRect(x: 23, y: (height - 16) / 2, width: width - 29, height: 16)
        addSubview(label)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize { frame.size }

    public func update(text: String, tint: NSColor) {
        label.stringValue = text
        layer?.backgroundColor = tint.withAlphaComponent(0.35).cgColor
    }
}
