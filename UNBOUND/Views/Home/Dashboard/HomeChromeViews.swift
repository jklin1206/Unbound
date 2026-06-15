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

struct HomeIconCommand: View {
    let artwork: HomeCommandArtworkKind
    let title: String
    let value: String
    let tint: Color
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                HomeCommandMiniGlyph(kind: artwork, tint: tint)
                    .frame(width: 30, height: 30)
                    .shadow(color: tint.opacity(0.22), radius: 6)

                Text(value.uppercased())
                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                    .fixedSize(horizontal: true, vertical: false)

                Text(title.uppercased())
                    .font(.system(size: 8.7, weight: .black, design: .monospaced))
                    .tracking(0.65)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.64)
                    .allowsTightening(true)
                    .frame(height: 22, alignment: .top)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 79)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct HomeCommandMiniGlyph: View {
    let kind: HomeCommandArtworkKind
    let tint: Color

    // A bordered icon chip (not a bare floating symbol) so the commands read as
    // defined controls instead of a flat tinted glyph. Scales to whatever frame
    // the caller gives it.
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                            .strokeBorder(tint.opacity(0.5), lineWidth: 1)
                    )

                Image(systemName: systemName)
                    .font(.system(size: side * 0.44, weight: .black))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .rotationEffect(.degrees(rotation))
            }
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
