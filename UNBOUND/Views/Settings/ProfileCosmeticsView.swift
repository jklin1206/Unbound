import SwiftUI

struct ProfileCosmeticsView: View {
    @EnvironmentObject private var services: ServiceContainer

    @State private var currentTier: SkillTier = .initiate
    @State private var unlockedTiers: [SkillTier] = [.initiate]
    @State private var equippedFrameTier: RankTitle = .initiate
    @State private var equippedBackgroundTier: RankTitle = .initiate
    @State private var equippedProfileColorTier: RankTitle = .initiate

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                cosmeticGrid(title: "Avatar Frame", selected: equippedFrameTier, mode: .frame)
                cosmeticGrid(title: "Profile Backdrop", selected: equippedBackgroundTier, mode: .background)
                cosmeticGrid(title: "Profile Color", selected: equippedProfileColorTier, mode: .color)
            }
            .padding(20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Profile Cosmetics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CUSTOMIZE")
                .font(Font.unbound.captionS.weight(.black))
                .tracking(2.0)
                .foregroundStyle(currentTier.rewardTextTint)
            Text("Profile Cosmetics")
                .font(Font.unbound.titleM)
                .foregroundStyle(Color.unbound.textPrimary)
            Text("Rank frames, backdrops, and profile colors stay unlocked once earned.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
            Text("\(unlockedTiers.count)/\(SkillTier.allCases.count) unlocked")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(currentTier.rewardTextTint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(currentTier.rewardTint.opacity(0.16)))
                .overlay(Capsule().strokeBorder(currentTier.rewardTint.opacity(0.34), lineWidth: 1))
                .padding(.top, 2)
        }
    }

    private func cosmeticGrid(title: String, selected: RankTitle, mode: CosmeticMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textSecondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(SkillTier.allCases, id: \.self) { tier in
                    let unlocked = unlockedTiers.contains(tier)
                    CosmeticOptionTile(
                        tier: tier,
                        mode: mode,
                        isUnlocked: unlocked,
                        isSelected: selected == tier.rankTitle
                    ) {
                        guard unlocked else { return }
                        switch mode {
                        case .frame:
                            equipFrame(tier)
                        case .background:
                            equipBackground(tier)
                        case .color:
                            equipProfileColor(tier)
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        currentTier = await services.rank.aggregateTier(userId: userId)
        unlockedTiers = RankCosmetics.unlockedTiers(userId: userId, currentTier: currentTier)
        equippedFrameTier = RankCosmetics.equippedFrameTier(userId: userId, currentTier: currentTier)
        equippedBackgroundTier = RankCosmetics.equippedBackgroundTier(userId: userId, currentTier: currentTier)
        equippedProfileColorTier = RankCosmetics.equippedProfileColorTier(userId: userId, currentTier: currentTier)
    }

    @MainActor
    private func equipFrame(_ tier: SkillTier) {
        let userId = services.auth.currentUserId ?? "anonymous"
        RankCosmetics.setEquippedFrameTier(tier, userId: userId, currentTier: currentTier)
        equippedFrameTier = RankCosmetics.equippedFrameTier(userId: userId, currentTier: currentTier)
        UnboundHaptics.soft()
    }

    @MainActor
    private func equipBackground(_ tier: SkillTier) {
        let userId = services.auth.currentUserId ?? "anonymous"
        RankCosmetics.setEquippedBackgroundTier(tier, userId: userId, currentTier: currentTier)
        equippedBackgroundTier = RankCosmetics.equippedBackgroundTier(userId: userId, currentTier: currentTier)
        UnboundHaptics.soft()
    }

    @MainActor
    private func equipProfileColor(_ tier: SkillTier) {
        let userId = services.auth.currentUserId ?? "anonymous"
        RankCosmetics.setEquippedProfileColorTier(tier, userId: userId, currentTier: currentTier)
        equippedProfileColorTier = RankCosmetics.equippedProfileColorTier(userId: userId, currentTier: currentTier)
        UnboundHaptics.soft()
    }
}

private enum CosmeticMode {
    case frame
    case background
    case color
}

private struct CosmeticOptionTile: View {
    let tier: SkillTier
    let mode: CosmeticMode
    let isUnlocked: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview
                    .frame(height: 72)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: isSelected ? 1.8 : 1)
                    )
                    .saturation(isUnlocked ? 1 : 0.10)
                    .opacity(isUnlocked ? 1 : 0.45)

                Text(tier.displayName.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(isUnlocked ? Color.unbound.textPrimary : Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? tier.rewardTint.opacity(0.16) : Color.unbound.surface.opacity(0.74))
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(tier.rewardTextTint)
                        .padding(6)
                } else if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(7)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }

    @ViewBuilder
    private var preview: some View {
        switch mode {
        case .frame:
            ZStack {
                Color.unbound.bg
                CosmeticAvatar(tier: tier.rankTitle, size: 62, letterFallback: "U")
            }
        case .background:
            ZStack {
                if let asset = RankCosmetics.profileBackgroundAsset(for: tier.rankTitle),
                   let ui = UIImage(named: asset) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    tier.rewardTint.opacity(0.24)
                }
                LinearGradient(
                    colors: [.clear, Color.unbound.bg.opacity(0.56)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        case .color:
            ZStack {
                Color.unbound.bg
                LinearGradient(
                    colors: tier.rankTitle.rewardGlowColors.map { $0.opacity(0.54) } + [Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: tier.rankTitle.rewardGlowColors.map { $0.opacity(0.42) } + [.clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: 82
                )
                VStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(tier.rewardTint.opacity(0.16 - Double(index) * 0.025))
                            .frame(height: 2)
                            .padding(.horizontal, CGFloat(index * 8 + 8))
                    }
                }
            }
        }
    }

    private var borderColor: Color {
        isSelected ? tier.rewardTextTint : tier.rewardTint.opacity(isUnlocked ? 0.34 : 0.16)
    }
}
