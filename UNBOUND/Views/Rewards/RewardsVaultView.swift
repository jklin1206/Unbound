import SwiftUI

// MARK: - RewardsVaultView
//
// The unified "Rewards / How to Earn" map. Browses every cosmetic reward —
// titles, skill-tree skins, profile cosmetics, and badges — showing each one's
// earned-vs-locked state and its unlock path, plus a "Next up" hook surfacing
// the nearest unlocks. Read-only overview; equipping stays in the dedicated
// screens this links to (SkinPickerView / ProfileCosmeticsView / BadgeGalleryView).

struct RewardsVaultView: View {
    @EnvironmentObject private var services: ServiceContainer
    @ObservedObject private var skinService = SkinService.shared
    @State private var aggregateTier: SkillTier = .initiate

    private var userId: String { services.auth.currentUserId ?? "anonymous" }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                summaryHeader
                nextUpSection
                ForEach(groups) { group in
                    groupSection(group)
                }
                Spacer().frame(height: 40)
            }
            .padding(20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Rewards")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            aggregateTier = await RankService.shared.aggregateTier(userId: userId)
        }
    }

    // MARK: - Header

    private var totalEarned: Int { groups.reduce(0) { $0 + $1.earned } }
    private var totalAll: Int { groups.reduce(0) { $0 + $1.total } }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR COLLECTION")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(2)
                .foregroundStyle(Color.unbound.accent)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(totalEarned)")
                    .font(Font.unbound.displayXL)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .monospacedDigit()
                Text("/ \(totalAll) unlocked")
                    .font(Font.unbound.bodyM)
                    .foregroundStyle(Color.unbound.textSecondary)
            }
            ProgressView(value: Double(totalEarned), total: Double(max(totalAll, 1)))
                .tint(Color.unbound.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Next up

    private var nextUp: [Reward] {
        var picks: [Reward] = []
        if let skin = skinRewards.first(where: { !$0.unlocked }) { picks.append(skin) }
        if let tier = cosmeticRewards.first(where: { !$0.unlocked }) { picks.append(tier) }
        if let title = titleRewards
            .filter({ !$0.unlocked && ($0.progress ?? 0) > 0 })
            .max(by: { ($0.progress ?? 0) < ($1.progress ?? 0) }) {
            picks.append(title)
        }
        return Array(picks.prefix(3))
    }

    @ViewBuilder
    private var nextUpSection: some View {
        if !nextUp.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("NEXT UP")
                    .font(Font.unbound.captionS.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(Color.unbound.textTertiary)
                ForEach(nextUp) { reward in
                    nextUpRow(reward)
                }
            }
        }
    }

    private func nextUpRow(_ reward: Reward) -> some View {
        HStack(spacing: 10) {
            rewardEmblem(reward, size: 40, locked: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(reward.name)
                    .font(Font.unbound.bodyMStrong)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .allowsTightening(true)
                Text(reward.requirement)
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let progress = reward.progress, let text = reward.progressText {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(text)
                        .font(Font.unbound.monoS.weight(.bold))
                        .foregroundStyle(reward.swatch)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .allowsTightening(true)
                    ProgressView(value: progress)
                        .tint(reward.swatch)
                        .frame(width: 48)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(reward.swatch.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Category section

    private func groupSection(_ group: Group) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(Font.unbound.titleS)
                        .foregroundStyle(Color.unbound.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .allowsTightening(true)
                    Text(group.subtitle)
                        .font(Font.unbound.captionS)
                        .foregroundStyle(Color.unbound.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                        .allowsTightening(true)
                }
                Spacer(minLength: 0)
                Text("\(group.earned) / \(group.total)")
                    .font(Font.unbound.monoS.weight(.bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(1)
                if group.destination != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }
            .contentShape(Rectangle())
            .overlay(equipLink(group.destination))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.rewards) { reward in
                        rewardTile(reward)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func equipLink(_ destination: EquipDestination?) -> some View {
        if let destination {
            NavigationLink {
                destination.view.environmentObject(services)
            } label: { Color.clear }
            .opacity(0) // invisible tap target over the header row
        }
    }

    private func rewardTile(_ reward: Reward) -> some View {
        VStack(spacing: 7) {
            rewardEmblem(reward, size: 52, locked: !reward.unlocked)
            Text(reward.name)
                .font(Font.unbound.captionS.weight(.semibold))
                .foregroundStyle(reward.unlocked ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .multilineTextAlignment(.center)
                .frame(height: 28, alignment: .top)
            if reward.unlocked {
                Text("EARNED")
                    .font(Font.unbound.monoS.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(reward.swatch)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            } else {
                Text(reward.progressText ?? reward.requirement)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 96)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    reward.unlocked ? reward.swatch.opacity(0.5) : Color.unbound.borderSubtle,
                    lineWidth: 1
                )
        )
    }

    private func rewardEmblem(_ reward: Reward, size: CGFloat, locked: Bool) -> some View {
        SwiftUI.Group {
            if let badge = badge(for: reward) {
                BadgeEmblemView(badge: badge, size: size, isUnlocked: !locked)
            } else {
                ZStack {
                    Circle()
                        .fill(reward.swatch.opacity(locked ? 0.12 : 0.22))
                    Circle()
                        .strokeBorder(reward.swatch.opacity(locked ? 0.4 : 0.9), lineWidth: 1.5)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: size * 0.3, weight: .bold))
                            .foregroundStyle(Color.unbound.textTertiary)
                    } else if let icon = reward.icon {
                        if let assetName = reward.assetName {
                            Image(assetName)
                                .resizable()
                                .scaledToFit()
                                .padding(size * 0.06)
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: size * 0.36, weight: .bold))
                                .foregroundStyle(reward.swatch)
                        }
                    } else {
                        Circle()
                            .fill(reward.swatch)
                            .frame(width: size * 0.42, height: size * 0.42)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .opacity(locked ? 0.85 : 1)
    }

    private func badge(for reward: Reward) -> Badge? {
        guard reward.id.hasPrefix("badge:") else { return nil }
        let id = String(reward.id.dropFirst("badge:".count))
        return BadgeCatalog.byId[id]
    }

    // MARK: - Aggregated model

    private struct Reward: Identifiable {
        let id: String
        let name: String
        let unlocked: Bool
        let requirement: String
        let swatch: Color
        let icon: String?
        var assetName: String? = nil
        var progress: Double? = nil
        var progressText: String? = nil
    }

    private struct Group: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let rewards: [Reward]
        let destination: EquipDestination?
        var earned: Int { rewards.filter(\.unlocked).count }
        var total: Int { rewards.count }
    }

    private enum EquipDestination {
        case skins, profileCosmetics, badges

        @ViewBuilder var view: some View {
            switch self {
            case .skins: SkinPickerView()
            case .profileCosmetics: ProfileCosmeticsView()
            case .badges: BadgeGalleryView()
            }
        }
    }

    private var groups: [Group] {
        [
            Group(id: "titles", title: "Titles",
                  subtitle: "Completed vows unlock titles",
                  rewards: titleRewards, destination: nil),
            Group(id: "skins", title: "Skill-tree skins",
                  subtitle: "Climb aggregate rank for skins",
                  rewards: skinRewards, destination: .skins),
            Group(id: "cosmetics", title: "Profile cosmetics",
                  subtitle: "Frames, backdrops, colors",
                  rewards: cosmeticRewards, destination: .profileCosmetics),
            Group(id: "badges", title: "Badges",
                  subtitle: "Earn through milestones",
                  rewards: badgeRewards, destination: .badges)
        ]
    }

    private static let titleThresholds: [(count: Int, tier: TitleID.Tier)] = [
        (3, .bronze), (7, .silver), (15, .gold)
    ]

    private var titleRewards: [Reward] {
        let state = WeeklyVowsService.shared.state(userId: userId)
        let unlocked = Set(state.unlockedTitles)
        let knownTitles = TitleCatalog.all
        let extraUnlockedTitles = state.unlockedTitles.filter { !knownTitles.contains($0) }
        return (knownTitles + extraUnlockedTitles).map { tid in
            let isUnlocked = unlocked.contains(tid)
            let need = Self.titleThresholds.first { $0.tier == tid.tier }?.count ?? 0
            let (label, have): (String, Int) = {
                switch tid.path {
                case .axis(let key):      return (key.buildVocab, state.completionsByAxis[key] ?? 0)
                case .cardKind(let kind): return (kind.displayName, state.completionsByCardKind[kind] ?? 0)
                case .badge:              return ("badge", 0)
                case .shop:               return ("shop", 0)
                case .squadSeasonWinner:  return ("squad season leaderboard", 0)
                }
            }()
            let requirement: String = {
                switch tid.path {
                case .squadSeasonWinner:
                    return "Finish #1 on the squad season leaderboard"
                default:
                    return "\(need) \(label) vows completed"
                }
            }()
            let fraction = need > 0 ? min(1.0, Double(have) / Double(need)) : nil
            return Reward(
                id: "title:\(tid.displayName)",
                name: tid.displayName,
                unlocked: isUnlocked,
                requirement: requirement,
                swatch: tierTint(tid.tier),
                icon: "seal.fill",
                assetName: tid.rewardAssetName,
                progress: isUnlocked ? nil : fraction,
                progressText: isUnlocked ? nil : "\(min(have, need)) / \(need)"
            )
        }
    }

    private var skinRewards: [Reward] {
        let unlocked = Set(skinService.unlockedSkins)
        return SkillTreeSkin.allCases.map { skin in
            Reward(
                id: "skin:\(skin.rawValue)",
                name: skin.displayName,
                unlocked: unlocked.contains(skin),
                requirement: skin.unlockHintCopy,
                swatch: skin.primaryColor,
                icon: nil
            )
        }
    }

    private var cosmeticRewards: [Reward] {
        let unlocked = Set(RankCosmetics.unlockedTiers(userId: userId, currentTier: aggregateTier))
        return RankTier.allCases.map { tier in
            let isUnlocked = unlocked.contains(tier)
            return Reward(
                id: "cosmetic:\(tier.rawValue)",
                name: tier.displayName,
                unlocked: isUnlocked,
                requirement: tier == .initiate ? "Starter set" : "Reach \(tier.displayName)",
                swatch: cosmeticTint(tier),
                icon: "person.crop.circle.badge.checkmark"
            )
        }
    }

    private var badgeRewards: [Reward] {
        BadgeService.shared.allBadges(userId: userId).map { badge in
            Reward(
                id: "badge:\(badge.id)",
                name: badge.displayName,
                unlocked: badge.isUnlocked,
                requirement: badge.unlockCriteria,
                swatch: badge.rarity.tint,
                icon: badge.iconSystemName
            )
        }
    }

    // MARK: - Tints

    private func tierTint(_ tier: TitleID.Tier) -> Color {
        switch tier {
        case .bronze: return Color.skinHex("CD7F32")
        case .silver: return Color.skinHex("C0C0C0")
        case .gold:   return Color.skinHex("FFC857")
        }
    }

    private func cosmeticTint(_ tier: RankTier) -> Color {
        Color.unbound.accent.opacity(0.45 + Double(tier.rawValue) / 18.0)
    }
}
