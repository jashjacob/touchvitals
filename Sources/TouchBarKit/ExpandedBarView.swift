import AppKit
import MetricsCore

/// The full widget row shown when the expanded Touch Bar is presented: network speed on the
/// left, a mini download-rate history sparkline in the middle, disk capacity on the right.
public final class ExpandedBarView: NSView {
    private let network = NetworkWidgetView()
    private let sparkline = SparklineView(width: 60, height: 30)
    private let disk = DiskWidgetView()

    /// Last 30 download-rate samples (~30s at the Scheduler's ~1s tick) feeding the sparkline.
    private var downHistory = RingBuffer<Double>(capacity: 30)

    public init() {
        let width = network.intrinsicContentSize.width + sparkline.intrinsicContentSize.width
            + disk.intrinsicContentSize.width
        let height = max(network.intrinsicContentSize.height, disk.intrinsicContentSize.height)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))

        network.frame.origin = .zero
        addSubview(network)

        sparkline.frame.origin = NSPoint(x: network.frame.width, y: 0)
        addSubview(sparkline)

        disk.frame.origin = NSPoint(x: network.frame.width + sparkline.frame.width, y: 0)
        addSubview(disk)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func updateNetwork(downBytesPerSec: Double, upBytesPerSec: Double) {
        network.update(downBytesPerSec: downBytesPerSec, upBytesPerSec: upBytesPerSec)
        downHistory.append(downBytesPerSec)
        sparkline.update(points: SparklineFormatter.normalizedPoints(downHistory.inChronologicalOrder()))
    }

    public func updateDisk(totalBytes: UInt64, availableBytes: UInt64) {
        disk.update(totalBytes: totalBytes, availableBytes: availableBytes)
    }
}
