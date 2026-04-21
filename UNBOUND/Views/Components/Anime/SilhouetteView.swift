import SwiftUI

enum SilhouetteRimLight {
    case dim
    case neutral
    case impact

    var color: Color {
        switch self {
        case .dim: return Color.unbound.textTertiary
        case .neutral: return Color.unbound.accent
        case .impact: return Color.unbound.impact
        }
    }

    var intensity: Double {
        switch self {
        case .dim: return 0.25
        case .neutral: return 0.6
        case .impact: return 1.0
        }
    }
}

enum BodyAsset: String {
    case frontMale = "body_front_male"
    case backMale = "body_back_male"
    /// Featureless, no-muscle-definition body used for Arc02 "dormant" state.
    case dormant = "dormant_body"
}

struct SilhouetteView: View {
    var rimLight: SilhouetteRimLight = .neutral
    var chromaticAberration: Double = 0.0
    var breathe: Bool = false
    var scale: CGFloat = 1.0
    var asset: BodyAsset? = .frontMale

    @State private var breatheAmount: CGFloat = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let wobble = chromaticAberration > 0 ? CGFloat(sin(t * 8)) * CGFloat(chromaticAberration) : 0

            ZStack {
                RadialGradient(
                    colors: [rimLight.color.opacity(rimLight.intensity * 0.35), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 260
                )
                .frame(width: 460, height: 460)
                .blur(radius: 12)

                if asset != nil {
                    renderedBody
                        .scaleEffect(scale * (breathe ? breatheAmount : 1.0))
                        .overlay(alignment: .center) {
                            if chromaticAberration > 0 {
                                ZStack {
                                    renderedBody
                                        .colorMultiply(.red)
                                        .opacity(0.35)
                                        .offset(x: -wobble, y: 0)
                                        .blendMode(.screen)
                                    renderedBody
                                        .colorMultiply(.cyan)
                                        .opacity(0.35)
                                        .offset(x: wobble, y: 0)
                                        .blendMode(.screen)
                                }
                                .scaleEffect(scale * (breathe ? breatheAmount : 1.0))
                            }
                        }
                } else {
                    if chromaticAberration > 0 {
                        symbolShape
                            .foregroundStyle(Color.red.opacity(0.5))
                            .offset(x: -wobble, y: 0)
                            .blendMode(.screen)
                        symbolShape
                            .foregroundStyle(Color.cyan.opacity(0.5))
                            .offset(x: wobble, y: 0)
                            .blendMode(.screen)
                    }
                    symbolShape
                        .foregroundStyle(Color.black.opacity(0.95))
                        .overlay(
                            symbolShape
                                .foregroundStyle(rimLight.color.opacity(rimLight.intensity))
                                .blur(radius: 1.2)
                                .blendMode(.screen)
                        )
                        .animeGlow(
                            color: rimLight.color,
                            radius: 28,
                            intensity: rimLight.intensity
                        )
                        .scaleEffect(scale * (breathe ? breatheAmount : 1.0))
                }
            }
        }
        .onAppear {
            guard breathe else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breatheAmount = 1.02
            }
        }
    }

    @ViewBuilder
    private var renderedBody: some View {
        if let asset {
            Image(asset.rawValue)
                .resizable()
                .scaledToFit()
                .frame(height: 520)
        }
    }

    private var symbolShape: some View {
        Image(systemName: "figure.stand")
            .resizable()
            .scaledToFit()
            .frame(width: 180, height: 320)
    }
}

#Preview("Front — dim") {
    ZStack {
        AnimeBackdrop(variant: .desaturated)
        SilhouetteView(rimLight: .dim, chromaticAberration: 1.2, asset: .frontMale)
    }
}

#Preview("Front — impact + breathe") {
    ZStack {
        AnimeBackdrop(variant: .godRay)
        SilhouetteView(rimLight: .impact, breathe: true, asset: .frontMale)
    }
}

#Preview("Back — impact") {
    ZStack {
        AnimeBackdrop(variant: .godRay)
        SilhouetteView(rimLight: .impact, asset: .backMale)
    }
}

#Preview("SF Symbol fallback") {
    ZStack {
        AnimeBackdrop(variant: .smoky)
        SilhouetteView(rimLight: .neutral, asset: nil)
    }
}
