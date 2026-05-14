// UNBOUND/Views/Components/AttributeHex.swift
import SwiftUI

struct AttributeHex: View {
    /// 0...100 per axis. Renders the filled "current" polygon.
    let current: [AttributeKey: Double]
    /// Optional dashed peak overlay. Pass nil to omit.
    let peak: [AttributeKey: Double]?
    /// Show "POW/AGI/..." axis labels around the hex.
    var showLabels: Bool = true
    /// Outer radius in points. Hex is drawn within a square box of side = 2*radius.
    let radius: CGFloat

    private let axisOrder: [AttributeKey] = [.power, .agility, .control, .endurance, .mobility, .explosiveness]

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            drawGrid(ctx: ctx, center: center)
            drawAxes(ctx: ctx, center: center)
            if let peak { drawPolygon(ctx: ctx, center: center, values: peak, dashed: true) }
            drawPolygon(ctx: ctx, center: center, values: current, dashed: false)
        }
        .frame(width: 2 * radius, height: 2 * radius)
        .overlay { if showLabels { labelOverlay } }
    }

    private func point(for index: Int, at fraction: Double, center: CGPoint) -> CGPoint {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * (2 * .pi / 6)
        let r = radius * CGFloat(fraction)
        return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
    }

    private func drawGrid(ctx: GraphicsContext, center: CGPoint) {
        for fraction in [1.0 / 3, 2.0 / 3, 1.0] {
            var path = Path()
            for i in 0..<6 {
                let p = point(for: i, at: fraction, center: center)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            ctx.stroke(path, with: .color(Color.unbound.border), lineWidth: 1)
        }
    }

    private func drawAxes(ctx: GraphicsContext, center: CGPoint) {
        for i in 0..<6 {
            var path = Path()
            path.move(to: center)
            path.addLine(to: point(for: i, at: 1.0, center: center))
            ctx.stroke(path, with: .color(Color.unbound.border), lineWidth: 1)
        }
    }

    private func drawPolygon(ctx: GraphicsContext, center: CGPoint, values: [AttributeKey: Double], dashed: Bool) {
        var path = Path()
        for (i, key) in axisOrder.enumerated() {
            let fraction = max(0, min(1, (values[key] ?? 0) / 100))
            let p = point(for: i, at: fraction, center: center)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        if dashed {
            ctx.stroke(path, with: .color(Color.unbound.textTertiary), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        } else {
            ctx.fill(path, with: .color(Color.unbound.accent.opacity(0.30)))
            ctx.stroke(path, with: .color(Color.unbound.accent), lineWidth: 1.5)
        }
    }

    @ViewBuilder
    private var labelOverlay: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let labelRadius = radius + 16
            ForEach(Array(axisOrder.enumerated()), id: \.offset) { (idx, key) in
                let angle = -CGFloat.pi / 2 + CGFloat(idx) * (2 * .pi / 6)
                Text(key.shortCode)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .position(
                        x: center.x + cos(angle) * labelRadius,
                        y: center.y + sin(angle) * labelRadius
                    )
            }
        }
    }
}
