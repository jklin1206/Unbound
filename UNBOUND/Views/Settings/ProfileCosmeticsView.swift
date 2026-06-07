import SwiftUI

struct ProfileCosmeticsView: View {
    @EnvironmentObject private var services: ServiceContainer

    @StateObject private var inventory = ShopInventoryStore.shared
    @State private var currentTier: SkillTier = .initiate
    @State private var unlockedFrameTiers: [SkillTier] = [.initiate]
    @State private var unlockedBackgroundTiers: [SkillTier] = [.initiate]
    @State private var unlockedProfileColorTiers: [SkillTier] = [.initiate]
    @State private var equippedFrameTier: RankTitle = .initiate
    @State private var equippedBackgroundTier: RankTitle = .initiate
    @State private var equippedProfileColorTier: RankTitle = .initiate
    @State private var equippedShopProfileBorder: ShopProfileBorderID?
    @State private var equippedProfileBackdrop: ShopItem?

    private let openShop: ((ShopCategory) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    private let shopColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    init(openShop: ((ShopCategory) -> Void)? = nil) {
        self.openShop = openShop
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                cosmeticGrid(title: "Avatar Frame", selected: equippedFrameTier, mode: .frame)
                cosmeticGrid(title: "Rank Backdrop", selected: equippedBackgroundTier, mode: .background)
                cosmeticGrid(title: "Profile Color", selected: equippedProfileColorTier, mode: .color)
                shopCosmeticGrid(title: "Shop Borders", items: shopBorderItems)
                shopCosmeticGrid(title: "Shop Backdrops", items: shopBackdropItems)
            }
            .padding(20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Profile Cosmetics")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .shopInventoryChanged)) { _ in
            refreshShopCosmetics()
        }
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
            Text("Rank rewards stay unlocked once earned. Shop borders and profile backdrops can override them.")
                .font(Font.unbound.captionS)
                .foregroundStyle(Color.unbound.textSecondary)
            Text("\(unlockedCosmeticCount)/\(SkillTier.allCases.count * 3) unlocked")
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
            let unlockedTiers = unlockedTiers(for: mode)

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
                        isSelected: isRankCosmeticSelected(tier, selected: selected, mode: mode)
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

    private func shopCosmeticGrid(title: String, items: [ShopItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(Color.unbound.textSecondary)

            LazyVGrid(columns: shopColumns, spacing: 10) {
                ForEach(items) { item in
                    ProfileShopCosmeticTile(
                        item: item,
                        isOwned: inventory.isPurchased(item),
                        isSelected: isShopCosmeticSelected(item),
                        actionTitle: shopActionTitle(for: item)
                    ) {
                        primaryShopAction(for: item)
                    }
                }
            }
        }
    }

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        inventory.bind(userId: userId)
        let confirmedRank = OverallRankTrialStore.shared.load(userId: userId).currentRank
        currentTier = RankCosmetics.equipped(highestRank: confirmedRank)
        unlockedFrameTiers = RankCosmetics.unlockedFrameTiers(userId: userId, currentTier: currentTier)
        unlockedBackgroundTiers = RankCosmetics.unlockedBackgroundTiers(userId: userId, currentTier: currentTier)
        unlockedProfileColorTiers = RankCosmetics.unlockedProfileColorTiers(userId: userId, currentTier: currentTier)
        equippedFrameTier = RankCosmetics.equippedFrameTier(userId: userId, currentTier: currentTier)
        equippedBackgroundTier = RankCosmetics.equippedBackgroundTier(userId: userId, currentTier: currentTier)
        equippedProfileColorTier = RankCosmetics.equippedProfileColorTier(userId: userId, currentTier: currentTier)
        refreshShopCosmetics(userId: userId)
    }

    @MainActor
    private func equipFrame(_ tier: SkillTier) {
        let userId = services.auth.currentUserId ?? "anonymous"
        RankCosmetics.setEquippedFrameTier(tier, userId: userId, currentTier: currentTier)
        ShopInventoryStore.clearEquippedProfileBorder(userId: userId)
        equippedFrameTier = RankCosmetics.equippedFrameTier(userId: userId, currentTier: currentTier)
        refreshShopCosmetics(userId: userId)
        UnboundHaptics.soft()
    }

    @MainActor
    private func equipBackground(_ tier: SkillTier) {
        let userId = services.auth.currentUserId ?? "anonymous"
        RankCosmetics.setEquippedBackgroundTier(tier, userId: userId, currentTier: currentTier)
        ShopInventoryStore.clearEquippedBackdrop(for: .profile, userId: userId)
        equippedBackgroundTier = RankCosmetics.equippedBackgroundTier(userId: userId, currentTier: currentTier)
        refreshShopCosmetics(userId: userId)
        UnboundHaptics.soft()
    }

    @MainActor
    private func equipProfileColor(_ tier: SkillTier) {
        let userId = services.auth.currentUserId ?? "anonymous"
        RankCosmetics.setEquippedProfileColorTier(tier, userId: userId, currentTier: currentTier)
        equippedProfileColorTier = RankCosmetics.equippedProfileColorTier(userId: userId, currentTier: currentTier)
        UnboundHaptics.soft()
    }

    @MainActor
    private func primaryShopAction(for item: ShopItem) {
        guard inventory.isPurchased(item) else {
            openShop?(item.category)
            return
        }

        switch item.reward {
        case .profileBorder(let border):
            inventory.setEquippedProfileBorder(border)
        case .profileBackground:
            inventory.setEquippedBackdrop(item, for: .profile)
        default:
            return
        }

        refreshShopCosmetics()
        UnboundHaptics.soft()
    }

    @MainActor
    private func refreshShopCosmetics(userId overrideUserId: String? = nil) {
        let userId = overrideUserId ?? services.auth.currentUserId ?? "anonymous"
        inventory.bind(userId: userId)
        equippedShopProfileBorder = ShopInventoryStore.equippedProfileBorder(userId: userId)
        equippedProfileBackdrop = ShopInventoryStore.equippedBackdrop(for: .profile, userId: userId)
    }

    private func isRankCosmeticSelected(_ tier: SkillTier, selected: RankTitle, mode: CosmeticMode) -> Bool {
        switch mode {
        case .frame:
            return equippedShopProfileBorder == nil && selected == tier.rankTitle
        case .background:
            return equippedProfileBackdrop == nil && selected == tier.rankTitle
        case .color:
            return selected == tier.rankTitle
        }
    }

    private func isShopCosmeticSelected(_ item: ShopItem) -> Bool {
        switch item.reward {
        case .profileBorder(let border):
            return equippedShopProfileBorder == border
        case .profileBackground:
            return equippedProfileBackdrop?.id == item.id
        default:
            return false
        }
    }

    private func shopActionTitle(for item: ShopItem) -> String {
        if isShopCosmeticSelected(item) { return "Active" }
        if inventory.isPurchased(item) { return "Use" }
        return openShop == nil ? "Locked" : "Shop"
    }

    private var shopBorderItems: [ShopItem] {
        ShopCatalog.items(for: .profileBorder)
    }

    private var shopBackdropItems: [ShopItem] {
        ShopCatalog.items(for: .backdrop).filter { item in
            if case .profileBackground = item.reward {
                return true
            }
            return false
        }
    }

    private var unlockedCosmeticCount: Int {
        unlockedFrameTiers.count + unlockedBackgroundTiers.count + unlockedProfileColorTiers.count
    }

    private func unlockedTiers(for mode: CosmeticMode) -> [SkillTier] {
        switch mode {
        case .frame:
            return unlockedFrameTiers
        case .background:
            return unlockedBackgroundTiers
        case .color:
            return unlockedProfileColorTiers
        }
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

private struct ProfileShopCosmeticTile: View {
    let item: ShopItem
    let isOwned: Bool
    let isSelected: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                preview
                    .aspectRatio(previewAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? item.accent.opacity(0.92) : Color.unbound.borderSubtle, lineWidth: isSelected ? 1.8 : 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(isOwned ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .frame(minHeight: 36, alignment: .topLeading)

                    HStack(alignment: .center, spacing: 6) {
                        Text((isOwned ? item.rarity : "Shop").uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(isOwned ? item.rarityTint : Color.unbound.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        Spacer(minLength: 0)

                        Text(actionTitle.uppercased())
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(0.7)
                            .foregroundStyle(actionForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.56)
                            .frame(width: 58, height: 27)
                            .background(Capsule().fill(actionBackground))
                    }
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? item.accent.opacity(0.14) : Color.unbound.surface.opacity(0.74))
            )
            .opacity(isOwned ? 1 : 0.62)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.unbound.rankGold)
                        .padding(6)
                } else if !isOwned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(7)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isSelected || (!isOwned && actionTitle == "Locked"))
    }

    private var previewAspectRatio: CGFloat {
        switch item.reward {
        case .profileBackground:
            return ShopBackdropArtworkPreview.aspectRatio
        default:
            return 1
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch item.reward {
        case .profileBorder(let border):
            ZStack {
                LinearGradient(
                    colors: item.colors.map { $0.opacity(0.82) } + [Color.unbound.surfaceElevated],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ShopPreviewLinework(color: border.accent)
                    .opacity(0.20)
                Circle()
                    .fill(Color.unbound.bg.opacity(0.82))
                    .frame(width: 48, height: 48)
                if let ui = UIImage(named: border.assetName) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78, height: 78)
                        .shadow(color: border.accent.opacity(0.34), radius: 8)
                } else {
                    Circle()
                        .strokeBorder(border.accent, lineWidth: 6)
                        .frame(width: 66, height: 66)
                }
            }
        case .profileBackground(let background):
            ShopBackdropArtworkPreview(
                assetName: background.assetName,
                accent: background.accent,
                symbolName: "person.crop.rectangle.stack.fill",
                symbolSize: 20,
                isMuted: !isOwned,
                scrimOpacity: 0.42
            )
        default:
            ZStack {
                Color.unbound.surfaceElevated
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(item.accent)
            }
        }
    }

    private var actionBackground: Color {
        if isSelected { return Color.unbound.rankGold.opacity(0.18) }
        if !isOwned { return Color.unbound.surfaceElevated }
        return item.accent.opacity(0.22)
    }

    private var actionForeground: Color {
        if isSelected { return Color.unbound.rankGold }
        return isOwned ? Color.unbound.textPrimary : Color.unbound.textTertiary
    }
}
