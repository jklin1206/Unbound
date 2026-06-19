import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

enum UnboundAdaptiveBackdropTextShadow {
    case dark
    case light
    case none
}

struct UnboundAdaptiveBackdropTextCandidate {
    let color: Color
    let relativeLuminance: CGFloat
    let shadow: UnboundAdaptiveBackdropTextShadow

    init(color: Color, uiColor: UIColor, shadow: UnboundAdaptiveBackdropTextShadow) {
        self.color = color
        relativeLuminance = uiColor.unboundRelativeLuminance
        self.shadow = shadow
    }
}

struct UnboundAdaptiveBackdropBrightPreference {
    let minimumAverage: CGFloat
    let minimumContrastMultiplier: CGFloat
    let minimumContrastFloor: CGFloat
    let minimumAverageContrast: CGFloat

    static let heroTitle = UnboundAdaptiveBackdropBrightPreference(
        minimumAverage: 0.22,
        minimumContrastMultiplier: 0.44,
        minimumContrastFloor: 1.36,
        minimumAverageContrast: 2.70
    )

    static let heroBody = UnboundAdaptiveBackdropBrightPreference(
        minimumAverage: 0.20,
        minimumContrastMultiplier: 0.42,
        minimumContrastFloor: 1.30,
        minimumAverageContrast: 2.45
    )

    static let accent = UnboundAdaptiveBackdropBrightPreference(
        minimumAverage: 0.18,
        minimumContrastMultiplier: 0.40,
        minimumContrastFloor: 1.22,
        minimumAverageContrast: 1.72
    )
}

extension Array where Element == UnboundAdaptiveBackdropTextCandidate {
    static var unboundBackdropPrimary: [UnboundAdaptiveBackdropTextCandidate] {
        return [
            UnboundAdaptiveBackdropTextCandidate(
                color: Color.unbound.textPrimary,
                uiColor: UIColor(Color.unbound.textPrimary),
                shadow: .dark
            )
        ]
    }

    static var unboundBackdropBody: [UnboundAdaptiveBackdropTextCandidate] {
        return [
            UnboundAdaptiveBackdropTextCandidate(
                color: Color.unbound.textPrimary,
                uiColor: UIColor(Color.unbound.textPrimary),
                shadow: .dark
            )
        ]
    }

    static var unboundBackdropMeta: [UnboundAdaptiveBackdropTextCandidate] {
        return [
            UnboundAdaptiveBackdropTextCandidate(
                color: Color.unbound.textPrimary,
                uiColor: UIColor(Color.unbound.textPrimary),
                shadow: .dark
            )
        ]
    }

    static func unboundBackdropAccent(_ tint: Color) -> [UnboundAdaptiveBackdropTextCandidate] {
        return [
            UnboundAdaptiveBackdropTextCandidate(
                color: Color.unbound.textPrimary,
                uiColor: UIColor(Color.unbound.textPrimary),
                shadow: .dark
            )
        ]
    }
}
