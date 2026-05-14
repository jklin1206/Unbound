import SwiftUI

/// Pill-shaped chip rendering a SkillTier as text + brand-flavored backdrop.
/// Bottom 4 tiers (Initiate–Forged): muted gray-violet, low-key.
/// Top 5 tiers (Veteran–Ascendant): violet accent with glow intensity
/// scaling on ordinal. Vessel/Unbound/Ascendant pop the most.
///
/// Used on skill-tree node chips (per-skill rank) and the profile rank
/// surface ("Ascendant Skills" list).
struct TierBadge: View {
    let tier: SkillTier
    var compact: Bool = false

    var body: some View {
        let glowIntensity = max(0, Double(tier.rawValue - SkillTier.veteran.rawValue)) * 0.25
        Text(tier.displayName.uppercased())
            .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(textColor)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(
                Capsule().fill(backgroundColor)
            )
            .overlay(
                Capsule().strokeBorder(strokeColor, lineWidth: 1)
            )
            .shadow(color: Color.unbound.accent.opacity(glowIntensity), radius: 6)
    }

    private var textColor: Color {
        tier.rawValue >= SkillTier.veteran.rawValue
            ? Color.unbound.textPrimary
            : Color.unbound.textSecondary
    }

    private var backgroundColor: Color {
        tier.rawValue >= SkillTier.veteran.rawValue
            ? Color.unbound.accent.opacity(0.18)
            : Color.unbound.surface
    }

    private var strokeColor: Color {
        tier.rawValue >= SkillTier.veteran.rawValue
            ? Color.unbound.accent.opacity(0.4)
            : Color.unbound.border
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
