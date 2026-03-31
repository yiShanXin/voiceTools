import AppKit

final class WaveformView: NSView {
    private let weights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private var barLayers: [CALayer] = []
    private var envelope: CGFloat = 0
    var barColor: NSColor = NSColor.white.withAlphaComponent(0.95) {
        didSet {
            for bar in barLayers {
                bar.backgroundColor = barColor.cgColor
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    func update(level: CGFloat) {
        let clamped = max(0, min(1, level))
        let smoothing: CGFloat = clamped > envelope ? 0.40 : 0.15
        envelope += (clamped - envelope) * smoothing
        redrawBars()
    }

    private func setupBars() {
        layer?.masksToBounds = false
        for _ in 0..<5 {
            let bar = CALayer()
            bar.backgroundColor = barColor.cgColor
            bar.cornerRadius = 1.8
            layer?.addSublayer(bar)
            barLayers.append(bar)
        }
        redrawBars()
    }

    private func redrawBars() {
        let totalWidth = bounds.width
        let totalHeight = bounds.height
        let barWidth: CGFloat = 6
        let spacing: CGFloat = (totalWidth - barWidth * 5) / 4
        let minHeight: CGFloat = 5
        let maxHeight = totalHeight

        for (index, bar) in barLayers.enumerated() {
            let jitter = CGFloat.random(in: 0.96...1.04)
            let scaled = max(0, min(1, envelope * weights[index] * jitter))
            let barHeight = minHeight + (maxHeight - minHeight) * scaled
            let x = CGFloat(index) * (barWidth + spacing)
            let y = (totalHeight - barHeight) / 2
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bar.frame = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            CATransaction.commit()
        }
    }

    override func layout() {
        super.layout()
        redrawBars()
    }
}
