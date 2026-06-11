import SwiftUI

/// Pill-shaped chip rendering a SkillTier as text + its canonical badge tint.
///
/// Used on skill-tree node chips (per-skill rank) and the profile rank
/// surface ("Ascendant Skills" list).
struct TierBadge: View {
    let tier: SkillTier
    var compact: Bool = false

    var body: some View {
        let glowIntensity = max(0, Double(tier.rawValue - SkillTier.veteran.rawValue)) * 0.25
        let tint = tier.rewardTint
        HStack(spacing: compact ? 4 : 6) {
            Image(tier.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 16 : 22, height: compact ? 16 : 22)
            Text(tier.displayName.uppercased())
                .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(Capsule().fill(tint.opacity(tier.rawValue >= SkillTier.veteran.rawValue ? 0.18 : 0.10)))
        .overlay(Capsule().strokeBorder(tint.opacity(tier.rawValue >= SkillTier.veteran.rawValue ? 0.44 : 0.28), lineWidth: 1))
        .shadow(color: tint.opacity(glowIntensity), radius: 6)
    }

    private var textColor: Color {
        tier.rawValue >= SkillTier.veteran.rawValue
            ? Color.unbound.textPrimary
            : Color.unbound.textSecondary
    }

}

#Preview("All Tiers") {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(SkillTier.allCases, id: \.self) { tier in
            HStack {
                TierBadge(tier: tier)
                TierBadge(tier: tier, compact: true)
            }
        }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color.unbound.bg)
}
