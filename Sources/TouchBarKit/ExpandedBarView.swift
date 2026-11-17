import AppKit

/// The full widget row shown when the expanded Touch Bar is presented: network speed on the
/// left, disk capacity on the right, side by side in one Touch Bar slot item.
public final class ExpandedBarView: NSView {
    private let network = NetworkWidgetView()
    private let disk = DiskWidgetView()

    public init() {
        let width = network.intrinsicContentSize.width + disk.intrinsicContentSize.width
        let height = max(network.intrinsicContentSize.height, disk.intrinsicContentSize.height)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))

        network.frame.origin = .zero
        addSubview(network)

        disk.frame.origin = NSPoint(x: network.frame.width, y: 0)
        addSubview(disk)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func updateNetwork(downBytesPerSec: Double, upBytesPerSec: Double) {
        network.update(downBytesPerSec: downBytesPerSec, upBytesPerSec: upBytesPerSec)
    }

    public func updateDisk(totalBytes: UInt64, availableBytes: UInt64) {
        disk.update(totalBytes: totalBytes, availableBytes: availableBytes)
    }
}
