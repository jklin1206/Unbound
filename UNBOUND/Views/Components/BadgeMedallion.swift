import SwiftUI

// MARK: - BadgeMedallion
//
// One cohesive, rendered badge — replaces the 46 mismatched PNG medallions. It
// styles every badge consistently from its SF-symbol glyph + rarity (steel /
// cyan / gold metal frame, recessed disc, glow), and renders a locked state.
// Premium + uniform, with zero asset churn.

struct BadgeMedallion: View {
    let iconSystemName: String
    let rarity: Badge.Rarity
    var size: CGFloat = 92
    var unlocked: Bool = true

    var body: some View {
        ZStack {
            // Outer faceted metal frame.
            Hexagon()
                .fill(frameGradient)
                .overlay(Hexagon().inset(by: max(1, size * 0.02)).stroke(rim, lineWidth: max(1, size * 0.018)))
                .shadow(color: accent.opacity(unlocked ? 0.5 : 0), radius: size * 0.16)

            // Recessed inner disc.
            Hexagon()
                .inset(by: size * 0.135)
                .fill(LinearGradient(colors: [Color.unbound.surfaceElevated, Color.unbound.bg],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Hexagon().inset(by: size * 0.135).stroke(rim.opacity(0.45), lineWidth: 1))

            // Top gloss for depth.
            Hexagon()
                .inset(by: size * 0.135)
                .fill(LinearGradient(colors: [Color.white.opacity(0.16), .clear],
                                     startPoint: .top, endPoint: .center))
                .blendMode(.screen)

            // Glyph.
            Image(systemName: iconSystemName)
                .font(.system(size: size * 0.32, weight: .black))
                .foregroundStyle(unlocked ? accent : Color.unbound.textTertiary)
                .shadow(color: accent.opacity(unlocked ? 0.65 : 0), radius: size * 0.06)
        }
        .frame(width: size, height: size * 1.06)
        .saturation(unlocked ? 1 : 0.12)
        .opacity(unlocked ? 1 : 0.45)
    }

    private var accent: Color {
        switch rarity {
        case .common:    return Color(red: 0.80, green: 0.85, blue: 0.93)  // steel
        case .rare:      return Color.unbound.coachCyan
        case .legendary: return Color.unbound.rankGold
        }
    }

    private var rim: Color { accent.opacity(0.9) }

    private var frameGradient: LinearGradient {
        switch rarity {
        case .common:
            return LinearGradient(colors: [Color(red: 0.44, green: 0.48, blue: 0.54),
                                           Color(red: 0.18, green: 0.20, blue: 0.25)],
                                  startPoint: .top, endPoint: .bottom)
        case .rare:
            return LinearGradient(colors: [Color.unbound.coachCyan.opacity(0.9),
                                           Color(red: 0.07, green: 0.20, blue: 0.28)],
                                  startPoint: .top, endPoint: .bottom)
        case .legendary:
            return LinearGradient(colors: [Color.unbound.rankGold,
                                           Color(red: 0.46, green: 0.31, blue: 0.05)],
                                  startPoint: .top, endPoint: .bottom)
        }
    }
}
