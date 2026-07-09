import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Unbound Backdrop Scrims, Shields, Tone & Text Shadows
//
// Static legibility layers over backdrop art: poster scrims, text shields,
// sampled ink tone, and the legibility shadow modifiers.
// Split from UnboundBackdrops.swift.

struct UnboundPosterScrim: View {
    var tint: Color
    var topOpacity: Double = 0.34
    var midOpacity: Double = 0.50
    var bottomOpacity: Double = 0.92
    var sideOpacity: Double = 0.46
    var tintOpacity: Double = 0.12

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color.unbound.bg.opacity(topOpacity), location: 0),
                    .init(color: Color.unbound.bg.opacity(midOpacity), location: 0.50),
                    .init(color: Color.unbound.bg.opacity(bottomOpacity), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    tint.opacity(tintOpacity),
                    tint.opacity(tintOpacity * 0.36),
                    .clear
                ],
                center: UnitPoint(x: 0.88, y: 0.10),
                startRadius: 16,
                endRadius: 280
            )

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(sideOpacity), location: 0),
                    .init(color: Color.black.opacity(sideOpacity * 0.38), location: 0.46),
                    .init(color: Color.black.opacity(0.24), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

struct UnboundPosterTextShield: View {
    var leadingOpacity: Double = 0.76
    var topOpacity: Double = 0.58
    var bottomOpacity: Double = 0.74

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color.unbound.bg.opacity(topOpacity), location: 0),
                    .init(color: Color.unbound.bg.opacity(topOpacity * 0.64), location: 0.36),
                    .init(color: Color.unbound.bg.opacity(bottomOpacity), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(leadingOpacity), location: 0),
                    .init(color: Color.black.opacity(leadingOpacity * 0.54), location: 0.42),
                    .init(color: Color.clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            RadialGradient(
                colors: [
                    Color.black.opacity(leadingOpacity * 0.70),
                    Color.black.opacity(leadingOpacity * 0.24),
                    .clear
                ],
                center: UnitPoint(x: 0.24, y: 0.24),
                startRadius: 0,
                endRadius: 270
            )
        }
    }
}

struct UnboundBackdropTextTone {
    let usesDarkInk: Bool
    let primary: Color
    let secondary: Color
    let tertiary: Color

    static let lightInk = UnboundBackdropTextTone(
        usesDarkInk: false,
        primary: Color.unbound.textPrimary,
        secondary: Color.unbound.textPrimary.opacity(0.92),
        tertiary: Color.unbound.textSecondary
    )

    static let darkInk = UnboundBackdropTextTone(
        usesDarkInk: true,
        primary: Color(red: 0.055, green: 0.060, blue: 0.066),
        secondary: Color(red: 0.070, green: 0.076, blue: 0.084).opacity(0.94),
        tertiary: Color(red: 0.080, green: 0.088, blue: 0.098).opacity(0.90)
    )

    static func sampled(
        assetName: String,
        regions: [CGRect],
        brightThreshold: CGFloat = 0.52
    ) -> UnboundBackdropTextTone {
        guard let image = UIImage(named: assetName) else { return .lightInk }
        let luminances = regions.compactMap { image.unboundAverageLuminance(in: $0) }
        guard !luminances.isEmpty else { return .lightInk }

        let average = luminances.reduce(0, +) / CGFloat(luminances.count)
        let brightest = luminances.max() ?? average
        let score = (average * 0.78) + (brightest * 0.22)

        return score >= brightThreshold ? .darkInk : .lightInk
    }
}

struct UnboundTextLegibilityShadow: ViewModifier {
    var strength: Double = 1

    func body(content: Content) -> some View {
        let amount = CGFloat(strength)

        content
            .shadow(
                color: Color.black.opacity(0.72 * strength),
                radius: 4.5 * amount,
                x: 0,
                y: 1.5 * amount
            )
            .shadow(
                color: Color.black.opacity(0.38 * strength),
                radius: 16 * amount,
                x: 0,
                y: 7 * amount
            )
    }
}

struct UnboundBackdropTextShadow: ViewModifier {
    let tone: UnboundBackdropTextTone
    var strength: Double = 1

    @ViewBuilder
    func body(content: Content) -> some View {
        let amount = CGFloat(strength)

        if tone.usesDarkInk {
            content
                .shadow(
                    color: Color.white.opacity(0.18 * strength),
                    radius: 1.6 * amount,
                    x: 0,
                    y: 0.6 * amount
                )
                .shadow(
                    color: Color.black.opacity(0.16 * strength),
                    radius: 1.4 * amount,
                    x: 0,
                    y: 1.2 * amount
                )
        } else {
            content.unboundTextShadow(strength: strength)
        }
    }
}
