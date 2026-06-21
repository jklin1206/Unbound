import SwiftUI

enum OnboardingAssetGlyphShape {
    case chamfered
    case hexagon
    case circle
}

struct OnboardingAssetGlyph: View {
    let assetName: String
    var tint: Color = Color.unbound.accent
    var size: CGFloat = 36
    var imagePadding: CGFloat = 5
    var shape: OnboardingAssetGlyphShape = .chamfered
    var showsCornerMark = true

    var body: some View {
        ZStack {
            background

            Image(assetName)
                .resizable()
                .scaledToFit()
                .padding(imagePadding)
                .shadow(color: tint.opacity(0.36), radius: max(3, size * 0.16))

            if showsCornerMark {
                HUDHexagon()
                    .stroke(tint.opacity(0.72), lineWidth: 0.8)
                    .frame(width: max(8, size * 0.34), height: max(8, size * 0.34))
                    .offset(x: size * 0.35, y: -size * 0.35)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var background: some View {
        switch shape {
        case .chamfered:
            ChamferedRectangle(inset: max(4, size * 0.16))
                .fill(glyphGradient)
                .overlay(
                    ChamferedRectangle(inset: max(4, size * 0.16))
                        .stroke(tint.opacity(0.56), lineWidth: 1)
                )
        case .hexagon:
            HUDHexagon()
                .fill(glyphGradient)
                .overlay(
                    HUDHexagon()
                        .stroke(tint.opacity(0.56), lineWidth: 1)
                )
        case .circle:
            Circle()
                .fill(glyphGradient)
                .overlay(
                    Circle()
                        .stroke(tint.opacity(0.56), lineWidth: 1)
                )
        }
    }

    private var glyphGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.unbound.bg.opacity(0.74),
                tint.opacity(0.18),
                Color.unbound.surfaceElevated.opacity(0.66)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
