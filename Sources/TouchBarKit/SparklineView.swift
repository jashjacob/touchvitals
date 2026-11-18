import AppKit

/// Draws a mini history line from pre-normalized (0...1) points — SparklineFormatter.normalizedPoints
/// does the actual min-max math, so this view only has to plot what it's handed. Untestable by
/// design: it's pure AppKit drawing, same tier as DiskWidgetView's BarView.
public final class SparklineView: NSView {
    private var points: [Double] = []

    public init(width: CGFloat, height: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public override var intrinsicContentSize: NSSize { frame.size }

    public func update(points: [Double]) {
        self.points = points
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        guard points.count > 1 else { return }
        let stepX = bounds.width / CGFloat(points.count - 1)
        let linePath = NSBezierPath()
        // A filled area under the line (closed down to the baseline) reads as a data-rich graph
        // rather than a bare stroke — matching the area-chart look of menu-bar monitoring widgets.
        let fillPath = NSBezierPath()
        fillPath.move(to: NSPoint(x: 0, y: 0))

        for (index, point) in points.enumerated() {
            let x = CGFloat(index) * stepX
            let y = CGFloat(point) * bounds.height
            let p = NSPoint(x: x, y: y)
            if index == 0 {
                linePath.move(to: p)
            } else {
                linePath.line(to: p)
            }
            fillPath.line(to: p)
        }
        fillPath.line(to: NSPoint(x: bounds.width, y: 0))
        fillPath.close()

        NSColor.controlAccentColor.withAlphaComponent(0.25).setFill()
        fillPath.fill()

        NSColor.controlAccentColor.setStroke()
        linePath.lineWidth = 1.3
        linePath.stroke()
    }
}
