import Foundation
import SwiftUI
import UIKit

struct HomeBackgroundContrastScrim: View {
    let size: CGSize

    var body: some View {
        let longestSide = max(size.width, size.height)

        ZStack {
            Color.unbound.bg.opacity(0.18)

            LinearGradient(
                colors: [
                    Color.unbound.bg.opacity(0.46),
                    Color.unbound.bg.opacity(0.24),
                    Color.unbound.bg.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.unbound.bg.opacity(0.42),
                    Color.unbound.bg.opacity(0.18),
                    Color.unbound.bg.opacity(0.06)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            RadialGradient(
                colors: [
                    Color.unbound.bg.opacity(0.00),
                    Color.unbound.bg.opacity(0.46)
                ],
                center: UnitPoint(x: 0.54, y: 0.16),
                startRadius: longestSide * 0.16,
                endRadius: longestSide * 0.78
            )
        }
    }
}

enum HomeCommandArtworkKind {
    case rankTrial
    case trialKey
    case vow
    case shop
    case backdrops
    case rankLibrary
    case weight
}

struct HomeCommandMiniGlyph: View {
    let kind: HomeCommandArtworkKind
    let tint: Color

    // A bare, premium glyph — no chip, no border. The icon carries it with a soft
    // tint glow so it reads as a control without a box. Scales to the caller's frame.
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            Image(systemName: systemName)
                .font(.system(size: side * 0.68, weight: .black))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .rotationEffect(.degrees(rotation))
                .shadow(color: tint.opacity(0.45), radius: side * 0.16)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var systemName: String {
        switch kind {
        case .rankTrial:   return "flag.checkered"
        case .trialKey:    return "key.fill"
        case .vow:         return "link"
        case .shop:        return "bag.fill"
        case .backdrops:   return "photo.on.rectangle.angled"
        case .rankLibrary: return "list.bullet.rectangle.portrait.fill"
        case .weight:      return "scalemass.fill"
        }
    }

    // The gate key reads better angled than bolt-upright.
    private var rotation: Double {
        kind == .trialKey ? -45 : 0
    }
}
