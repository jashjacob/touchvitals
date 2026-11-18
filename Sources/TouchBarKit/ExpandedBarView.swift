import AppKit
import MetricsCore

/// A 1pt vertical divider between widget groups, inset from the top/bottom so it doesn't run
/// edge-to-edge — purely cosmetic, same tier as IconValueChip's drawing.
private final class SeparatorView: NSView {
    init(height: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 2, width: 1, height: height - 4))
        wantsLayer = true
        layer?.backgroundColor = NSColor.separatorColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// The full widget row shown when the expanded Touch Bar is presented: network speed + history,
/// CPU, memory, and disk capacity, left to right, each group separated by a thin divider.
public final class ExpandedBarView: NSView {
    private let network = NetworkWidgetView()
    private let networkSparkline: SparklineView?
    private let cpu: PercentSparklineWidgetView
    private let memory: PercentSparklineWidgetView
    private let disk = DiskWidgetView()
    private let gap: CGFloat = 10

    /// Last 30 download-rate samples (~30s at the Scheduler's ~1s tick) feeding the network sparkline.
    private var downHistory = RingBuffer<Double>(capacity: 30)

    /// `showGraphs` is read once at construction (GraphsPreference, in AppMain, can't be referenced
    /// from TouchBarKit) — toggling the menu bar preference takes effect on the next launch rather
    /// than live, so this layout's width stays fixed for the life of a run.
    public init(showGraphs: Bool = true) {
        networkSparkline = showGraphs ? SparklineView(width: 60, height: 30) : nil
        cpu = PercentSparklineWidgetView(symbolName: "cpu", showSparkline: showGraphs)
        memory = PercentSparklineWidgetView(symbolName: "memorychip", showSparkline: showGraphs)

        let groups: [NSView] = ([network, networkSparkline, cpu, memory, disk] as [NSView?]).compactMap { $0 }
        let height = groups.map { $0.intrinsicContentSize.height }.max() ?? 30
        let width = groups.reduce(0) { $0 + $1.intrinsicContentSize.width } + gap * CGFloat(groups.count - 1)
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))

        var x: CGFloat = 0
        for (index, view) in groups.enumerated() {
            view.frame.origin = NSPoint(x: x, y: 0)
            addSubview(view)
            x += view.frame.width
            guard index < groups.count - 1 else { continue }
            let separator = SeparatorView(height: height)
            separator.frame.origin.x = x + gap / 2
            addSubview(separator)
            x += gap
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func updateNetwork(downBytesPerSec: Double, upBytesPerSec: Double) {
        network.update(downBytesPerSec: downBytesPerSec, upBytesPerSec: upBytesPerSec)
        downHistory.append(downBytesPerSec)
        networkSparkline?.update(points: SparklineFormatter.normalizedPoints(downHistory.inChronologicalOrder()))
    }

    public func updateCPU(percent: Double) {
        cpu.update(percent: percent)
    }

    public func updateMemory(percent: Double) {
        memory.update(percent: percent)
    }

    public func updateDisk(totalBytes: UInt64, availableBytes: UInt64) {
        disk.update(totalBytes: totalBytes, availableBytes: availableBytes)
    }
}
