import SwiftUI

// MARK: - RankUpShareCard
//
// 2:3 vertical card (1080 x 1620) sized for IG story / TikTok frame share.
// Rendered to UIImage via ImageRenderer on tap from the cinematic.
//
// Layout (top → bottom):
//   - "UNBOUND" wordmark + archetype label
//   - Giant rank display (180pt mono, skin glow)
//   - Exercise name
//   - Archetype tagline beneath
//   - Footer: unboundapp.com + archetype pill
//
// Background: base dark + archetype-colored diagonal gradient + grid +
// ember particles + archetype hero watermark at 15% opacity.

struct RankUpShareCard: View {
    let rank: SubRank
    let exerciseDisplayName: String
    let archetypeDisplayName: String
    let archetype: Archetype
    let skin: SkillTreeSkin

    init(
        rank: SubRank,
        exerciseDisplayName: String,
        archetypeDisplayName: String,
        archetype: Archetype = .vTaper,
        skin: SkillTreeSkin = .violet
    ) {
        self.rank = rank
        self.exerciseDisplayName = exerciseDisplayName
        self.archetypeDisplayName = archetypeDisplayName
        self.archetype = archetype
        self.skin = skin
    }

    var body: some View {
        ZStack {
            // Base
            Color.unbound.bg.ignoresSafeArea()

            // Archetype diagonal gradient tint
            LinearGradient(
                colors: [
                    archetypeTint.opacity(0.55),
                    Color.unbound.bg,
                    skin.impactColor.opacity(0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)
            .opacity(0.85)

            // Grid texture
            TechGridBackground()
                .opacity(0.22)

            // Ember particles
            ParticleEmitter(config: .embers, isActive: true)
                .opacity(0.45)

            // Hero silhouette watermark
            archetypeSilhouette
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.15)

            VStack(spacing: 0) {
                header
                Spacer()
                rankBlock
                Spacer()
                footer
            }
            .padding(.vertical, 54)
            .padding(.horizontal, 36)
        }
        .frame(width: 1080, height: 1620)
        .background(Color.unbound.bg)
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 8) {
            Text("UNBOUND")
                .font(.system(size: 38, weight: .heavy, design: .monospaced))
                .tracking(6.0)
                .foregroundStyle(Color.unbound.textPrimary)
            Text(archetype.shortName)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .tracking(4.0)
                .foregroundStyle(archetypeTint)
        }
    }

    private var rankBlock: some View {
        VStack(spacing: 26) {
            Text("RANK UP")
                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                .tracking(8.0)
                .foregroundStyle(skin.primaryColor)

            Text(rank.displayName)
                .font(.system(size: 320, weight: .black, design: .monospaced))
                .foregroundStyle(Color.unbound.textPrimary)
                .shadow(color: skin.rimColor.opacity(0.75), radius: 32)
                .shadow(color: skin.impactColor.opacity(0.45), radius: 80)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(exerciseDisplayName.uppercased())
                .font(.system(size: 44, weight: .bold, design: .default))
                .tracking(3.0)
                .foregroundStyle(Color.unbound.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 24)
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Text(archetypeTagline.uppercased())
                .font(.system(size: 22, weight: .medium, design: .default))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 14) {
                Text("unboundapp.com")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                Circle()
                    .fill(Color.unbound.textTertiary)
                    .frame(width: 4, height: 4)
                Text("ARC · \(archetype.shortName)")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(archetypeTint)
            }
        }
    }

    // MARK: Archetype presentation

    private var archetypeTint: Color {
        switch archetype {
        case .heavyDuty: return Color(.sRGB, red: 0.72, green: 0.50, blue: 0.28, opacity: 1) // bronze
        case .leanCut:   return Color(.sRGB, red: 0.80, green: 0.22, blue: 0.30, opacity: 1) // crimson
        case .vTaper:    return Color.unbound.accent                                          // violet
        case .shredded:  return Color(.sRGB, red: 0.55, green: 0.60, blue: 0.66, opacity: 1) // steel
        }
    }

    private var archetypeTagline: String {
        switch archetype {
        case .heavyDuty: return "Take up space."
        case .leanCut:   return "Built like a fighter."
        case .vTaper:    return "Own the room."
        case .shredded:  return "Precision over bulk."
        }
    }

    @ViewBuilder
    private var archetypeSilhouette: some View {
        // Prefer the archetype-specific render (e.g. archetype_sovereign),
        // fall back to the generic male silhouette, and finally an SF Symbol
        // so the card still renders cleanly pre-asset.
        if let uiImage = UIImage(named: archetype.silhouetteAssetName)
            ?? UIImage(named: "body_unbound_front") {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 1200)
                .colorMultiply(archetypeTint)
                .blendMode(.screen)
        } else {
            Image(systemName: "figure.stand")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 620, height: 1100)
                .foregroundStyle(archetypeTint)
        }
    }
}

// MARK: Renderer helper

@MainActor
enum RankUpShareCardRenderer {
    /// Render the share card to UIImage at scale 3 (retina social quality).
    /// `skin` defaults to the active SkinService skin when nil.
    static func render(
        rank: SubRank,
        exerciseDisplayName: String,
        archetypeDisplayName: String,
        archetype: Archetype = .vTaper,
        skin: SkillTreeSkin? = nil
    ) -> UIImage? {
        let resolvedSkin = skin ?? SkinService.shared.currentSkin
        let card = RankUpShareCard(
            rank: rank,
            exerciseDisplayName: exerciseDisplayName,
            archetypeDisplayName: archetypeDisplayName,
            archetype: archetype,
            skin: resolvedSkin
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// Auto-generated caption for the system share sheet.
    static func caption(
        rank: SubRank,
        exerciseDisplayName: String
    ) -> String {
        """
        Just hit \(rank.displayName) on \(exerciseDisplayName). The arc continues. — via UNBOUND

        #UNBOUND #RankUp
        """
    }
}

#Preview {
    RankUpShareCard(
        rank: .bPlus,
        exerciseDisplayName: "Back Squat",
        archetypeDisplayName: "V-TAPER",
        archetype: .vTaper,
        skin: .violet
    )
    .scaleEffect(0.25)
}
