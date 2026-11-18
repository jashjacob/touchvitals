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
        let path = NSBezierPath()
        let stepX = bounds.width / CGFloat(points.count - 1)
        for (index, point) in points.enumerated() {
            let x = CGFloat(index) * stepX
            let y = CGFloat(point) * bounds.height
            if index == 0 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
}
