import SwiftUI

enum AnimeBackdropVariant {
    case smoky
    case godRay
    case desaturated
}

struct AnimeBackdrop: View {
    var variant: AnimeBackdropVariant = .smoky
    var intensity: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                Color.unbound.bg.ignoresSafeArea()
                if #available(iOS 18.0, *) {
                    meshLayer(t: t)
                        .ignoresSafeArea()
                        .opacity(intensity)
                } else {
                    fallbackLayer(t: t)
                        .ignoresSafeArea()
                        .opacity(intensity)
                }
                grainOverlay
                    .ignoresSafeArea()
                    .blendMode(.overlay)
                    .opacity(0.18)
            }
        }
    }

    @available(iOS 18.0, *)
    @ViewBuilder
    private func meshLayer(t: TimeInterval) -> some View {
        let drift: Float = Float(sin(t * 0.35)) * 0.06
        let drift2: Float = Float(cos(t * 0.5)) * 0.06
        let points: [SIMD2<Float>] = [
            SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5 + drift, 0.0), SIMD2<Float>(1.0, 0.0),
            SIMD2<Float>(0.0, 0.5 + drift2), SIMD2<Float>(0.5, 0.5), SIMD2<Float>(1.0, 0.5 - drift2),
            SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5 - drift, 1.0), SIMD2<Float>(1.0, 1.0)
        ]
        MeshGradient(
            width: 3,
            height: 3,
            points: points,
            colors: meshColors(t: t)
        )
    }

    @available(iOS 18.0, *)
    private func meshColors(t: TimeInterval) -> [Color] {
        switch variant {
        case .smoky:
            let pulse = 0.08 + 0.04 * sin(t * 0.6)
            return [
                Color.unbound.bg,
                Color.unbound.surface.opacity(0.9),
                Color.unbound.bg,
                Color.unbound.accent.opacity(pulse),
                Color.unbound.surfaceElevated,
                Color.unbound.accent.opacity(pulse * 0.7),
                Color.unbound.bg,
                Color.unbound.surface,
                Color.unbound.bg
            ]
        case .godRay:
            let warm = 0.22 + 0.08 * sin(t * 0.8)
            return [
                Color.unbound.bg,
                Color.unbound.accent.opacity(warm * 0.4),
                Color.unbound.bg,
                Color.unbound.accent.opacity(warm),
                Color.unbound.impact.opacity(warm * 0.8),
                Color.unbound.accent.opacity(warm * 0.6),
                Color.unbound.bg,
                Color.unbound.surface,
                Color.unbound.bg
            ]
        case .desaturated:
            return [
                Color.unbound.bg,
                Color.unbound.surface,
                Color.unbound.bg,
                Color.unbound.surfaceElevated.opacity(0.8),
                Color.unbound.border,
                Color.unbound.surfaceElevated.opacity(0.8),
                Color.unbound.bg,
                Color.unbound.surface,
                Color.unbound.bg
            ]
        }
    }

    @ViewBuilder
    private func fallbackLayer(t: TimeInterval) -> some View {
        switch variant {
        case .smoky:
            ZStack {
                RadialGradient(
                    colors: [Color.unbound.accent.opacity(0.14 + 0.05 * sin(t * 0.7)), .clear],
                    center: UnitPoint(x: 0.3 + 0.1 * sin(t * 0.3), y: 0.4),
                    startRadius: 20, endRadius: 380
                )
                RadialGradient(
                    colors: [Color.unbound.impact.opacity(0.08), .clear],
                    center: UnitPoint(x: 0.7 - 0.1 * cos(t * 0.4), y: 0.7),
                    startRadius: 10, endRadius: 320
                )
                LinearGradient(
                    colors: [Color.unbound.surface.opacity(0.6), Color.unbound.bg],
                    startPoint: .top, endPoint: .bottom
                )
                .blendMode(.multiply)
            }
        case .godRay:
            ZStack {
                RadialGradient(
                    colors: [
                        Color.unbound.accent.opacity(0.32 + 0.08 * sin(t * 0.9)),
                        Color.unbound.impact.opacity(0.2),
                        .clear
                    ],
                    center: .center,
                    startRadius: 30, endRadius: 420
                )
                RadialGradient(
                    colors: [Color.unbound.impact.opacity(0.18), .clear],
                    center: UnitPoint(x: 0.5, y: 0.2),
                    startRadius: 20, endRadius: 260
                )
            }
        case .desaturated:
            ZStack {
                LinearGradient(
                    colors: [Color.unbound.surface, Color.unbound.bg],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color.unbound.textTertiary.opacity(0.12), .clear],
                    center: .center,
                    startRadius: 40, endRadius: 340
                )
            }
        }
    }

    private var grainOverlay: some View {
        Canvas { ctx, size in
            var rng = SystemRandomNumberGenerator()
            for _ in 0..<180 {
                let x = CGFloat(UInt.random(in: 0..<UInt(size.width), using: &rng))
                let y = CGFloat(UInt.random(in: 0..<UInt(size.height), using: &rng))
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                ctx.fill(Path(rect), with: .color(.white.opacity(0.06)))
            }
        }
    }
}

#Preview("Smoky") {
    AnimeBackdrop(variant: .smoky)
}

#Preview("God ray") {
    AnimeBackdrop(variant: .godRay)
}

#Preview("Desaturated") {
    AnimeBackdrop(variant: .desaturated)
}
