import SwiftUI
import UIKit

struct EnergyFill: View {
    let tint: Color
    let cut: CGFloat
    let sweep: Bool   // one-shot shimmer when the bar completes

    @State private var sweepX: CGFloat = -0.45

    var body: some View {
        let shape = CutCornerBar(cut: cut)
        ZStack {
            shape.fill(
                LinearGradient(
                    colors: [tint, tint.opacity(0.82), tint.opacity(0.95)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            // Top gloss for glassy depth.
            shape.fill(
                LinearGradient(colors: [Color.white.opacity(0.45), .clear],
                               startPoint: .top, endPoint: .center)
            )
            .blendMode(.screen)
            // One-shot shimmer sweep on completion.
            GeometryReader { g in
                let w = max(1, g.size.width)
                shape.fill(
                    LinearGradient(colors: [.clear, Color.white.opacity(0.75), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: w * 0.32)
                .offset(x: w * sweepX)
                .blendMode(.screen)
                .opacity(sweep ? 1 : 0)
            }
        }
        .clipShape(shape)
        .onChange(of: sweep) { _, on in
            guard on else { return }
            sweepX = -0.45
            withAnimation(.easeOut(duration: 0.5)) { sweepX = 1.15 }
        }
    }
}

struct RPGStatBar: View {
    let from: Double
    let to: Double
    let tint: Color
    let animate: Bool
    var height: CGFloat = 18
    var segments: Int = 10
    var showOriginCap: Bool = false
    var originAssetName: String? = nil
    var endpointAssetName: String? = nil
    var tickAssetName: String? = nil
    /// Only fire the end flourish (shimmer sweep + cap ignite) on a celebratory
    /// completion — i.e. a level-up. A plain fill stays clean and readable.
    var celebrate: Bool = false
    /// When set, the parent drives the fill directly (used by the level-up
    /// choreography: fill→100→reset→refill). The bar skips its own staging.
    var controlledProgress: Double? = nil
    /// Parent-triggered flourish (cap ignite + shimmer) for the controlled path.
    var forceFlourish: Bool = false

    @State private var displayedProgress: Double = 0
    @State private var reachedEnd = false

    private var flourish: Bool {
        controlledProgress != nil ? forceFlourish : (reachedEnd && celebrate)
    }
    private var fillProgress: Double { controlledProgress ?? displayedProgress }

    var body: some View {
        GeometryReader { geo in
            let capWidth = showOriginCap ? height * 1.55 : height * 0.70
            let rightCapWidth = height * 0.86
            // Pull the track left so the origin diamond sits at the fill origin
            // (otherwise the diamond floats too far left of the bar).
            let trackX = showOriginCap ? capWidth * 0.5 : capWidth * 0.72
            let trackWidth = max(24, geo.size.width - trackX - rightCapWidth * 0.72)
            let trackHeight = height * 0.54

            ZStack(alignment: .leading) {
                // Left origin ornament. This is vector so it scales perfectly.
                OriginCap(tint: tint, hot: flourish, ornate: showOriginCap, assetName: originAssetName)
                    .frame(width: capWidth, height: height)
                    .position(x: capWidth / 2, y: height / 2)
                    .zIndex(3)

                // Main track frame.
                CutCornerBar(cut: trackHeight * 0.42)
                    .fill(Color.unbound.bg.opacity(0.92))
                    .frame(width: trackWidth, height: trackHeight)
                    .overlay(
                        CutCornerBar(cut: trackHeight * 0.42)
                            .strokeBorder(Color.unbound.textPrimary.opacity(0.34), lineWidth: 1)
                    )
                    .overlay(alignment: .leading) {
                        CutCornerBar(cut: trackHeight * 0.42)
                            .fill(tint.opacity(0.18))
                            .frame(width: trackWidth * min(1, max(0, from)))
                    }
                    .overlay(alignment: .leading) {
                        let fillWidth = trackWidth * min(1, max(0, fillProgress))
                        EnergyFill(tint: tint, cut: trackHeight * 0.42, sweep: flourish)
                            .frame(width: fillWidth, height: trackHeight)
                            .overlay(alignment: .trailing) {
                                // Glowing head — blooms only on a celebratory completion.
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: trackHeight * 0.5, height: trackHeight)
                                    .blur(radius: trackHeight * 0.32)
                                    .opacity(flourish ? 0.95 : 0)
                                    .shadow(color: tint, radius: trackHeight * 0.6)
                                    .shadow(color: tint.opacity(0.8), radius: trackHeight)
                                    .animation(.easeOut(duration: 0.25), value: flourish)
                            }
                            .shadow(color: tint.opacity(flourish ? 0.6 : 0.32), radius: height * 0.38)
                    }
                    .overlay {
                        HStack(spacing: 0) {
                            ForEach(0..<segments, id: \.self) { index in
                                if index > 0 {
                                    BarTick(assetName: tickAssetName)
                                        .frame(width: showOriginCap ? 6 : 4, height: trackHeight * 1.55)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .position(x: trackX + trackWidth / 2, y: height / 2)
                    .zIndex(1)

                // Right end cap — ignites when the energy reaches it.
                EndCap(tint: tint, ignited: flourish, assetName: endpointAssetName)
                    .frame(width: rightCapWidth, height: height * 0.78)
                    .position(x: trackX + trackWidth, y: height / 2)
                    .zIndex(2)
            }
            .frame(width: geo.size.width, height: height)
        }
        .frame(height: height)
        .onAppear { stageFill() }
        .onChange(of: animate) { _, _ in stageFill() }
        .onChange(of: to) { _, _ in stageFill() }
    }

    private func stageFill() {
        guard controlledProgress == nil else { return }   // parent drives the fill
        displayedProgress = min(1, max(0, from))
        reachedEnd = false
        guard animate else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 1.05)) {
                displayedProgress = min(1, max(0, to))
            }
        }
        // The flourish — shimmer sweep + end-cap ignite — lands as the fill completes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18 + 1.05) {
            reachedEnd = true
        }
    }
}

struct OriginCap: View {
    let tint: Color
    let hot: Bool
    let ornate: Bool
    let assetName: String?

    var body: some View {
        ZStack {
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(ornate ? 1.45 : 1.25)
                    .shadow(color: hot ? tint.opacity(0.42) : .clear, radius: 8)
            } else {
                DiamondShard()
                    .fill(
                        LinearGradient(
                            colors: hot
                                ? [tint, tint.opacity(0.7), Color.unbound.bg]
                                : [Color.unbound.surfaceElevated, Color.unbound.bg],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(DiamondShard().stroke(Color.unbound.textPrimary.opacity(0.50), lineWidth: 1))
                    .shadow(color: hot ? tint.opacity(0.55) : .clear, radius: 9)
                DiamondShard()
                    .stroke(tint.opacity(hot ? 0.95 : 0.72), lineWidth: 1)
                    .padding(ornate ? 3 : 5)
                if ornate {
                    Rectangle()
                        .fill(tint.opacity(0.72))
                        .frame(width: 2, height: 18)
                        .rotationEffect(.degrees(35))
                }
            }
        }
    }
}

struct EndCap: View {
    let tint: Color
    let ignited: Bool
    let assetName: String?

    var body: some View {
        ZStack {
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(1.18)
                    .shadow(color: tint.opacity(ignited ? 0.7 : 0.26), radius: ignited ? 11 : 5)
            } else {
                DiamondShard()
                    .fill(
                        LinearGradient(
                            colors: ignited
                                ? [Color.white, tint, tint.opacity(0.82)]
                                : [Color.unbound.surfaceElevated, Color.unbound.bg],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(DiamondShard().stroke(
                        ignited ? Color.white.opacity(0.85) : Color.unbound.textPrimary.opacity(0.45),
                        lineWidth: 1))
                    .shadow(color: ignited ? tint.opacity(0.9) : .clear, radius: ignited ? 14 : 0)
                DiamondShard()
                    .stroke(tint.opacity(ignited ? 0.95 : 0.5), lineWidth: 1)
                    .padding(4)
            }
        }
        .scaleEffect(ignited ? 1.18 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.5), value: ignited)
    }
}

struct BarTick: View {
    let assetName: String?

    var body: some View {
        Group {
            if let assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.74)
            } else {
                Rectangle()
                    .fill(Color.unbound.bg.opacity(0.72))
                    .frame(width: 1)
            }
        }
    }
}

struct DiamondShard: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CutCornerBar: InsettableShape {
    var cut: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let c = min(cut, r.height / 2, r.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: r.minX + c, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.midY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> CutCornerBar {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
