import SwiftUI

struct DayZeroPortfolioHex: View {
    let current: [AttributeKey: Double]
    let radius: CGFloat
    var showsLabels: Bool = true

    private let axisOrder: [AttributeKey] = [.power, .vitality, .control, .endurance, .mobility, .explosiveness]

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            drawGrid(ctx: ctx, center: center)
            drawAxes(ctx: ctx, center: center)
            drawCurrent(ctx: ctx, center: center)
        }
        .frame(width: radius * 2.55, height: radius * 2.35)
        .overlay { if showsLabels { labels } }
    }

    private func point(for index: Int, at fraction: Double, center: CGPoint) -> CGPoint {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * (2 * .pi / 6)
        let r = radius * CGFloat(fraction)
        return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
    }

    private func hexPath(fraction: Double, center: CGPoint) -> Path {
        var path = Path()
        for i in 0..<axisOrder.count {
            let p = point(for: i, at: fraction, center: center)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    private func drawGrid(ctx: GraphicsContext, center: CGPoint) {
        for fraction in [0.33, 0.66, 1.0] {
            ctx.stroke(
                hexPath(fraction: fraction, center: center),
                with: .color(Color.unbound.textSecondary.opacity(fraction == 1.0 ? 0.42 : 0.2)),
                style: StrokeStyle(lineWidth: fraction == 1.0 ? 1.4 : 1.0, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawAxes(ctx: GraphicsContext, center: CGPoint) {
        for i in 0..<axisOrder.count {
            var path = Path()
            path.move(to: center)
            path.addLine(to: point(for: i, at: 1.0, center: center))
            ctx.stroke(
                path,
                with: .color(Color.unbound.textSecondary.opacity(0.18)),
                style: StrokeStyle(lineWidth: 1.0, lineCap: .round)
            )
        }
    }

    private func drawCurrent(ctx: GraphicsContext, center: CGPoint) {
        var path = Path()
        for (i, key) in axisOrder.enumerated() {
            let raw = max(0, min(100, current[key] ?? 0))
            let fraction = max(0.06, raw / 100)
            let p = point(for: i, at: fraction, center: center)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()

        ctx.fill(path, with: .color(Color.unbound.accent.opacity(0.22)))
        ctx.stroke(
            path,
            with: .color(Color.unbound.accent.opacity(0.95)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )
    }

    @ViewBuilder
    private var labels: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let labelRadius = radius + 26

            ForEach(Array(axisOrder.enumerated()), id: \.offset) { index, key in
                let angle = -CGFloat.pi / 2 + CGFloat(index) * (2 * .pi / 6)
                let level = Int((current[key] ?? 0).rounded())

                HStack(spacing: 4) {
                    Text(key.shortCode)
                    Text("\(level)")
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textSecondary.opacity(0.92))
                .frame(width: 58)
                .position(
                    x: center.x + cos(angle) * labelRadius,
                    y: center.y + sin(angle) * labelRadius
                )
            }
        }
    }
}

struct DayZeroDossierLinework: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.08, y: h * 0.12))
                    path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.05))
                    path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.12))
                    path.addLine(to: CGPoint(x: w * 0.95, y: h * 0.08))

                    path.move(to: CGPoint(x: w * 0.08, y: h * 0.72))
                    path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.88))
                    path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.82))
                    path.addLine(to: CGPoint(x: w * 0.94, y: h * 0.92))

                    path.move(to: CGPoint(x: w * 0.86, y: h * 0.04))
                    path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.58))
                    path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.96))
                }
                .stroke(color.opacity(0.42), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))

                ForEach(0..<5) { i in
                    Circle()
                        .fill(color.opacity(0.28))
                        .frame(width: 3, height: 3)
                        .position(
                            x: w * [0.18, 0.42, 0.66, 0.82, 0.30][i],
                            y: h * [0.18, 0.30, 0.20, 0.68, 0.78][i]
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
