// UNBOUND/Views/Components/AttributeHex.swift
import SwiftUI

struct AttributeHex: View {
    enum LabelVariant {
        case compact
        case profile
    }

    /// 0...100 hex-fill per axis. Renders the filled polygon.
    let current: [AttributeKey: Double]
    /// Optional permanent XP-derived level per axis. Falls back to a level
    /// derived from the fill fraction when absent.
    var levels: [AttributeKey: Int]? = nil
    /// Optional prestige tier labels to place under the axis level.
    var tiers: [AttributeKey: RankTitle]? = nil
    /// Show "POW/VIT/..." axis labels around the hex.
    var showLabels: Bool = true
    /// Controls how much detail the axis labels show.
    var labelVariant: LabelVariant = .compact
    /// Outer radius in points. Hex is drawn within a square box of side = 2*radius.
    let radius: CGFloat

    private let axisOrder: [AttributeKey] = [.power, .vitality, .control, .endurance, .mobility, .explosiveness]

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            drawGrid(ctx: ctx, center: center)
            drawAxes(ctx: ctx, center: center)
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
            ctx.stroke(path, with: .color(Color.unbound.textSecondary.opacity(0.56)), lineWidth: 1.6)
        }
    }

    private func drawAxes(ctx: GraphicsContext, center: CGPoint) {
        for i in 0..<6 {
            var path = Path()
            path.move(to: center)
            path.addLine(to: point(for: i, at: 1.0, center: center))
            ctx.stroke(path, with: .color(Color.unbound.textSecondary.opacity(0.46)), lineWidth: 1.35)
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
            ctx.stroke(path, with: .color(Color.unbound.textSecondary.opacity(0.72)), style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
        } else {
            ctx.fill(path, with: .color(Color.unbound.accent.opacity(0.38)))
            ctx.stroke(path, with: .color(Color.unbound.accent), lineWidth: 2.6)
        }
    }

    /// Level for `key`: the passed-in xp-derived level, else derived from the
    /// fill fraction (`fill% × maxLevel`).
    private func displayLevel(for key: AttributeKey) -> Int {
        if let level = levels?[key] { return level }
        let fraction = max(0, min(1, (current[key] ?? 0) / 100))
        return Int((fraction * Double(AttributeLevelCurve.maxLevel)).rounded())
    }

    @ViewBuilder
    private var labelOverlay: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let labelRadius = radius + labelRadiusInset
            ForEach(Array(axisOrder.enumerated()), id: \.offset) { (idx, key) in
                let angle = -CGFloat.pi / 2 + CGFloat(idx) * (2 * .pi / 6)
                axisLabelView(for: key)
                    .frame(width: labelWidth)
                .position(
                    x: center.x + cos(angle) * labelRadius,
                    y: center.y + sin(angle) * labelRadius
                )
            }
        }
    }

    @ViewBuilder
    private func axisLabelView(for key: AttributeKey) -> some View {
        VStack(spacing: 2) {
            if labelVariant == .profile {
                let level = displayLevel(for: key)
                Text(key.shortCode)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(0)
                    .foregroundStyle(key.rewardTint)
                    .lineLimit(1)
                Text("LVL \(level)")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0)
                    .foregroundStyle(Color.unbound.textSecondary.opacity(0.92))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            } else {
                let level = displayLevel(for: key)
                Text("\(key.shortCode) LVL \(level)")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(0)
                    .foregroundStyle(key.rewardTint.opacity(0.92))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var labelRadiusInset: CGFloat {
        switch labelVariant {
        case .compact:
            return 17
        case .profile:
            return 27
        }
    }

    private var labelWidth: CGFloat {
        switch labelVariant {
        case .compact:
            return 62
        case .profile:
            return 60
        }
    }
}

struct AttributeRankBadge: View {
    let rank: RankTitle
    var size: CGFloat

    var body: some View {
        Image(rank.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("\(rank.displayName) rank")
    }
}
