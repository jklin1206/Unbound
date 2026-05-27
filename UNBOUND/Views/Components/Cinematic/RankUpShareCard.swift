import SwiftUI

// MARK: - RankUpShareCard
//
// 2:3 vertical card (1080 x 1620) sized for IG story / TikTok frame share.
// Rendered to UIImage via ImageRenderer on tap from the cinematic.
//
// Layout (top → bottom):
//   - "UNBOUND" wordmark + build identity label
//   - Giant rank badge + named rank title
//   - Exercise name
//   - Build identity tagline beneath
//   - Footer: unboundapp.com + identity pill
//
// Background: base dark + diagonal gradient + grid + ember particles.

struct RankUpShareCard: View {
    let rank: SubRank
    let exerciseDisplayName: String
    let buildIdentity: BuildIdentity
    let skin: SkillTreeSkin

    init(
        rank: SubRank,
        exerciseDisplayName: String,
        buildIdentity: BuildIdentity,
        skin: SkillTreeSkin = .violet
    ) {
        self.rank = rank
        self.exerciseDisplayName = exerciseDisplayName
        self.buildIdentity = buildIdentity
        self.skin = skin
    }

    var body: some View {
        ZStack {
            // Base
            Color.unbound.bg.ignoresSafeArea()

            // Diagonal gradient tint (neutral accent)
            LinearGradient(
                colors: [
                    tint.opacity(0.55),
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
            Text(buildIdentity.displayName.uppercased())
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .tracking(4.0)
                .foregroundStyle(tint)
        }
    }

    private var rankBlock: some View {
        VStack(spacing: 26) {
            Text("RANK UP")
                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                .tracking(8.0)
                .foregroundStyle(skin.primaryColor)

            Image(rankTitle.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 280, height: 280)
                .shadow(color: tint.opacity(0.75), radius: 32)
                .shadow(color: tint.opacity(0.45), radius: 80)

            Text(rankTitle.displayName.uppercased())
                .font(.system(size: 72, weight: .black, design: .default))
                .tracking(5.0)
                .foregroundStyle(Color.unbound.textPrimary)
                .minimumScaleFactor(0.55)
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
            Text(tagline.uppercased())
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
                Text("ARC · \(buildIdentity.displayName.uppercased())")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(tint)
            }
        }
    }

    // MARK: Identity presentation

    private var rankTitle: RankTitle { rank.title }

    private var tint: Color { rankTitle.rewardTint }

    private var tagline: String { buildIdentity.tagline }
}

// MARK: Renderer helper

@MainActor
enum RankUpShareCardRenderer {
    /// Render the share card to UIImage at scale 3 (retina social quality).
    /// `skin` defaults to the active SkinService skin when nil.
    static func render(
        rank: SubRank,
        exerciseDisplayName: String,
        buildIdentity: BuildIdentity,
        skin: SkillTreeSkin? = nil
    ) -> UIImage? {
        let resolvedSkin = skin ?? SkinService.shared.currentSkin
        let card = RankUpShareCard(
            rank: rank,
            exerciseDisplayName: exerciseDisplayName,
            buildIdentity: buildIdentity,
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
        Just reached \(rank.title.displayName) on \(exerciseDisplayName). The arc continues. — via UNBOUND

        #UNBOUND #RankUp
        """
    }
}

#Preview {
    RankUpShareCard(
        rank: .bPlus,
        exerciseDisplayName: "Back Squat",
        buildIdentity: BuildIdentity(primary: .power, secondary: nil, shape: .specialist),
        skin: .violet
    )
    .scaleEffect(0.25)
}
