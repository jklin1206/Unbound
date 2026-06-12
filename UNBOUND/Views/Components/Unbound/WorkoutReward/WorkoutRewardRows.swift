import SwiftUI
import UIKit

struct RewardBadgeAsset: View {
    let unlock: BadgeUnlock
    let tint: Color

    var body: some View {
        let badge = BadgeCatalog.all.first { $0.id == unlock.id }
        BadgeMedallion(
            iconSystemName: badge?.iconSystemName ?? "rosette",
            rarity: badge?.rarity ?? (unlock.rankTier != nil ? .legendary : .rare),
            size: 54,
            unlocked: true
        )
        .accessibilityLabel(unlock.title)
    }
}

struct AttributeDeltaRow: View {
    let delta: AttributeDeltaReward

    var body: some View {
        HStack(spacing: 8) {
            Text(delta.key.shortCode)
                .font(Font.unbound.monoS.weight(.heavy))
                .foregroundStyle(delta.tint)
                .frame(width: 34, alignment: .leading)
            Text("+\(Int(delta.xpGained.rounded())) XP")
                .font(Font.unbound.monoS.weight(.semibold))
                .foregroundStyle(Color.unbound.textPrimary)
            Image(systemName: delta.didAdvanceTier ? "arrow.up.right.square.fill" : "arrow.up")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(delta.tint)
            Spacer(minLength: 0)
        }
    }
}

struct PRRewardRow: View {
    let pr: PersonalRecordReward

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if UIImage(named: "badge_art_pr_session") != nil {
                    Image("badge_art_pr_session")
                        .resizable()
                        .scaledToFit()
                        .shadow(color: pr.family.tint.opacity(0.35), radius: 10)
                } else {
                    ZStack {
                        Circle().fill(pr.family.tint.opacity(0.20))
                        Image(systemName: "target")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(pr.family.tint)
                    }
                }
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(pr.liftName.uppercased())
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(pr.deltaText.uppercased())
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
            Text(pr.valueText.uppercased())
                .font(Font.unbound.monoM.weight(.heavy))
                .foregroundStyle(pr.family.tint)
        }
    }
}

struct SegmentedArcProgress: View {
    let progress: Double
    let segments: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(segments, 1), id: \.self) { index in
                let filled = Double(index + 1) / Double(max(segments, 1)) <= progress + 0.001
                Rectangle()
                    .fill(filled ? tint : Color.unbound.surfaceElevated)
                    .frame(height: 18)
                    .overlay(Rectangle().stroke(Color.unbound.borderSubtle, lineWidth: 1))
                    .shadow(color: filled ? tint.opacity(0.35) : .clear, radius: 8)
            }
        }
    }
}

struct CosmeticUnlockRow: View {
    let unlock: CosmeticUnlockReward

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if UIImage(named: "badge_art_cosmetic_prism") != nil {
                    Image("badge_art_cosmetic_prism")
                        .resizable()
                        .scaledToFit()
                        .shadow(color: unlock.tint.opacity(0.35), radius: 12)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(colors: [unlock.tint.opacity(0.85), Color.unbound.textPrimary.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.unbound.textPrimary.opacity(0.6), lineWidth: 1))
                }
            }
            .frame(width: 52, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text("COSMETIC UNLOCKED")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(unlock.tint)
                Text(unlock.title.uppercased())
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                Text(unlock.subtitle)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
            Spacer()
        }
    }
}
