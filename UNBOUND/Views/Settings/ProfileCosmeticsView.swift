import SwiftUI

struct ProfileCosmeticsView: View {
    @EnvironmentObject private var services: ServiceContainer

    @StateObject private var inventory = ShopInventoryStore.shared
    @State private var currentTier: SkillTier = .initiate
    @State private var unlockedFrameTiers: [SkillTier] = [.initiate]
    @State private var unlockedBackgroundTiers: [SkillTier] = [.initiate]
    @State private var equippedFrameTier: RankTitle = .initiate
    @State private var equippedBackgroundTier: RankTitle = .initiate
    @State private var equippedShopProfileBorder: ShopProfileBorderID?
    @State private var equippedProfileBackdrop: ShopItem?
    @State private var selectedSurface: ProfileCosmeticSurface = .borders

    private let openShop: ((ShopCategory) -> Void)?

    init(openShop: ((ShopCategory) -> Void)? = nil) {
        self.openShop = openShop
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                surfaceSwitch
                cosmeticGrid
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
        HStack(alignment: .center, spacing: 12) {
            // Live avatar preview — reflects the currently equipped frame /
            // border so selecting one changes this instantly (the previous
            // generic icon gave no visual feedback that a pick took effect).
            CosmeticAvatar(
                tier: equippedShopProfileBorder == nil ? equippedFrameTier : .initiate,
                size: 52,
                letterFallback: "U",
                shopBorder: equippedShopProfileBorder
            )
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("PROFILE KIT")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                Text(activeCosmeticSummary)
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Text("\(rankUnlockedCount)/\(rankRewardCount)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(activeTint)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(activeTint.opacity(0.14)))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.92))
        )
    }

    private var cosmeticGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(profileRows) { row in
                CosmeticGridCard(
                    row: row,
                    state: optionState(for: row),
                    action: { primaryAction(for: row) }
                )
            }
        }
    }

    private var surfaceSwitch: some View {
        Picker("Profile cosmetic type", selection: $selectedSurface) {
            ForEach(ProfileCosmeticSurface.allCases) { surface in
                Label(surface.title, systemImage: surface.systemImage)
                    .tag(surface)
            }
        }
        .pickerStyle(.segmented)
    }

    @MainActor
    private func load() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        inventory.bind(userId: userId)
        // Unlocks follow the rank the app SHOWS the user: the profile's rank
        // plate displays the skill-aggregate tier, so gating cosmetics on the
        // trial-confirmed rank alone read as "can't equip my own rank". The
        // confirmed rank still counts (and the unlock ratchet keeps anything
        // earned permanent).
        let confirmedRank = OverallRankTrialStore.shared.load(userId: userId).currentRank
        let aggregate = await services.rank.aggregateTier(userId: userId)
        currentTier = RankCosmetics.equipped(highestRank: max(confirmedRank, aggregate))
        unlockedFrameTiers = RankCosmetics.unlockedFrameTiers(userId: userId, currentTier: currentTier)
        unlockedBackgroundTiers = RankCosmetics.unlockedBackgroundTiers(userId: userId, currentTier: currentTier)
        equippedFrameTier = RankCosmetics.equippedFrameTier(userId: userId, currentTier: currentTier)
        equippedBackgroundTier = RankCosmetics.equippedBackgroundTier(userId: userId, currentTier: currentTier)
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
    private func primaryAction(for row: ProfileCosmeticRow) {
        guard !isActionDisabled(row) else { return }

        switch row {
        case .rankFrame(let tier):
            guard unlockedFrameTiers.contains(tier) else { return }
            equipFrame(tier)
        case .rankBanner(let tier):
            guard unlockedBackgroundTiers.contains(tier) else { return }
            equipBackground(tier)
        case .shopBorder(let item):
            guard inventory.isPurchased(item) else {
                openShop?(item.category)
                return
            }
            if case .profileBorder(let border) = item.reward {
                inventory.setEquippedProfileBorder(border)
            }
            refreshShopCosmetics()
            UnboundHaptics.soft()
        case .shopBanner(let item):
            guard inventory.isPurchased(item) else {
                openShop?(item.category)
                return
            }
            inventory.setEquippedBackdrop(item, for: .profile)
            refreshShopCosmetics()
            UnboundHaptics.soft()
        }
    }

    @MainActor
    private func refreshShopCosmetics(userId overrideUserId: String? = nil) {
        let userId = overrideUserId ?? services.auth.currentUserId ?? "anonymous"
        inventory.bind(userId: userId)
        equippedShopProfileBorder = ShopInventoryStore.equippedProfileBorder(userId: userId)
        equippedProfileBackdrop = ShopInventoryStore.equippedBackdrop(for: .profile, userId: userId)
    }

    private var profileRows: [ProfileCosmeticRow] {
        switch selectedSurface {
        case .borders:
            return SkillTier.allCases.map(ProfileCosmeticRow.rankFrame)
                + shopBorderItems.map(ProfileCosmeticRow.shopBorder)
        case .banners:
            return SkillTier.allCases.map(ProfileCosmeticRow.rankBanner)
                + shopBannerItems.map(ProfileCosmeticRow.shopBanner)
        }
    }

    private func optionState(for option: ProfileCosmeticRow) -> ProfileCosmeticOptionState {
        ProfileCosmeticOptionState(
            isSelected: isSelected(option),
            isUnlockedOrOwned: isUnlockedOrOwned(option),
            statusTitle: statusTitle(for: option),
            actionTitle: actionTitle(for: option),
            isActionDisabled: isActionDisabled(option)
        )
    }

    private func isSelected(_ row: ProfileCosmeticRow) -> Bool {
        switch row {
        case .rankFrame(let tier):
            return equippedShopProfileBorder == nil && equippedFrameTier == tier.rankTitle
        case .rankBanner(let tier):
            return equippedProfileBackdrop == nil && equippedBackgroundTier == tier.rankTitle
        case .shopBorder(let item):
            if case .profileBorder(let border) = item.reward {
                return equippedShopProfileBorder == border
            }
            return false
        case .shopBanner(let item):
            return equippedProfileBackdrop?.id == item.id
        }
    }

    private func isUnlockedOrOwned(_ row: ProfileCosmeticRow) -> Bool {
        switch row {
        case .rankFrame(let tier):
            return unlockedFrameTiers.contains(tier)
        case .rankBanner(let tier):
            return unlockedBackgroundTiers.contains(tier)
        case .shopBorder(let item), .shopBanner(let item):
            return inventory.isPurchased(item)
        }
    }

    private func isActionDisabled(_ row: ProfileCosmeticRow) -> Bool {
        if isSelected(row) { return true }
        if isUnlockedOrOwned(row) { return false }
        return !(row.isShopItem && openShop != nil)
    }

    private func statusTitle(for row: ProfileCosmeticRow) -> String {
        if isSelected(row) { return "Active" }
        if isUnlockedOrOwned(row) { return row.isShopItem ? "Owned" : "Unlocked" }
        return row.isShopItem && openShop != nil ? "Shop" : "Locked"
    }

    private func actionTitle(for row: ProfileCosmeticRow) -> String {
        if isSelected(row) { return "Active" }
        if isUnlockedOrOwned(row) { return "Use" }
        return row.isShopItem && openShop != nil ? "Shop" : "Locked"
    }

    private var activeCosmeticSummary: String {
        let frame = equippedShopProfileBorder?.displayName ?? equippedFrameTier.displayName
        // Rank banners read as journey locations everywhere they're named.
        let banner = activeShopBanner?.name ?? equippedBackgroundTier.bannerLocationName
        return "\(frame) / \(banner)"
    }

    private var activeTint: Color {
        if let banner = activeShopBanner {
            return banner.accent
        }
        if let border = equippedShopProfileBorder {
            return border.accent
        }
        return equippedBackgroundTier.rewardTint
    }

    private var shopBorderItems: [ShopItem] {
        ShopCatalog.items(for: .profileBorder)
    }

    private var shopBannerItems: [ShopItem] {
        ShopCatalog.items(for: .profileWallpaper)
            .filter { item in
                guard let assetName = item.backdropAssetName else { return false }
                return UIImage(named: assetName) != nil
            }
    }

    private var activeShopBanner: ShopItem? {
        guard let equippedProfileBackdrop,
              let assetName = equippedProfileBackdrop.backdropAssetName,
              UIImage(named: assetName) != nil
        else { return nil }
        return equippedProfileBackdrop
    }

    private var rankUnlockedCount: Int {
        unlockedFrameTiers.count + unlockedBackgroundTiers.count
    }

    private var rankRewardCount: Int {
        SkillTier.allCases.count * 2
    }
}

private struct ProfileCosmeticOptionState {
    let isSelected: Bool
    let isUnlockedOrOwned: Bool
    let statusTitle: String
    let actionTitle: String
    let isActionDisabled: Bool
}

private enum ProfileCosmeticSurface: String, CaseIterable, Identifiable {
    case borders
    case banners

    var id: String { rawValue }

    var title: String {
        switch self {
        case .borders:
            return "Borders"
        case .banners:
            return "Banners"
        }
    }

    var systemImage: String {
        switch self {
        case .borders:
            return "person.crop.circle.badge.sparkles"
        case .banners:
            return "person.crop.rectangle.stack"
        }
    }

    var headerTitle: String {
        switch self {
        case .borders:
            return "BORDER"
        case .banners:
            return "BANNER"
        }
    }
}

private enum ProfileCosmeticRow: Identifiable {
    case rankFrame(SkillTier)
    case rankBanner(SkillTier)
    case shopBorder(ShopItem)
    case shopBanner(ShopItem)

    var id: String {
        switch self {
        case .rankFrame(let tier):
            return "rank.frame.\(tier.token)"
        case .rankBanner(let tier):
            return "rank.banner.\(tier.token)"
        case .shopBorder(let item):
            return "shop.border.\(item.id)"
        case .shopBanner(let item):
            return "shop.banner.\(item.id)"
        }
    }

    var title: String {
        switch self {
        case .rankFrame(let tier):
            return "\(tier.displayName) Frame"
        case .rankBanner(let tier):
            // Journey-location names — the tier stays legible via the TIER
            // badge on the row.
            return tier.bannerLocationName
        case .shopBorder(let item), .shopBanner(let item):
            return item.name
        }
    }

    var sourceTitle: String {
        switch self {
        case .rankFrame, .rankBanner:
            return "Rank"
        case .shopBorder, .shopBanner:
            return "Shop"
        }
    }

    var typeTitle: String {
        switch self {
        case .rankFrame:
            return "Frame"
        case .shopBorder:
            return "Border"
        case .rankBanner, .shopBanner:
            return "Banner"
        }
    }

    var systemImage: String {
        switch self {
        case .rankFrame:
            return "person.crop.circle"
        case .shopBorder:
            return "person.crop.circle.badge.sparkles"
        case .rankBanner, .shopBanner:
            return "rectangle.fill"
        }
    }

    var accent: Color {
        switch self {
        case .rankFrame(let tier), .rankBanner(let tier):
            return tier.rewardTint
        case .shopBorder(let item), .shopBanner(let item):
            return item.accent
        }
    }

    var detail: String {
        switch self {
        case .rankFrame(let tier), .rankBanner(let tier):
            return "Tier \(tier.ordinal)"
        case .shopBorder(let item), .shopBanner(let item):
            return item.rarity
        }
    }

    var isShopItem: Bool {
        switch self {
        case .shopBorder, .shopBanner:
            return true
        case .rankFrame, .rankBanner:
            return false
        }
    }
}

// MARK: - CosmeticGridCard
//
// Friendlier visual tile (replaces the old vertical list row). Shows a large
// preview of the actual cosmetic on a calm dark tile — the avatar wearing the
// border/frame, or the banner art — with a status chip. Selected cards get an
// accent outline. No rainbow backdrops.

private struct CosmeticGridCard: View {
    let row: ProfileCosmeticRow
    let state: ProfileCosmeticOptionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                previewArea
                infoArea
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.unbound.surface.opacity(state.isSelected ? 0.98 : 0.80))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        state.isSelected ? row.accent.opacity(0.9) : Color.unbound.borderSubtle,
                        lineWidth: state.isSelected ? 1.8 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(state.isActionDisabled)
    }

    // MARK: Preview

    private var isBanner: Bool {
        switch row {
        case .rankBanner, .shopBanner: return true
        case .rankFrame, .shopBorder: return false
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        ZStack(alignment: .topTrailing) {
            // Calm neutral tile — intentionally de-colorized (the old preview
            // backdrops were garish rainbow gradients).
            Color.unbound.bg.opacity(0.55)

            preview
                .saturation(state.isUnlockedOrOwned ? 1 : 0.14)
                .opacity(state.isUnlockedOrOwned ? 1 : 0.5)
                // Center the art in the tile — the ZStack's topTrailing
                // alignment (for the state badge) was pinning avatar/border
                // previews into the top-right corner and clipping the ring.
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            stateBadge
                .padding(8)
        }
        .modifier(PreviewShape(isBanner: isBanner))
        .frame(maxWidth: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var preview: some View {
        switch row {
        case .rankFrame(let tier):
            CosmeticAvatar(tier: tier.rankTitle, size: 82, letterFallback: "U")
        case .shopBorder(let item):
            if case .profileBorder(let border) = item.reward {
                CosmeticAvatar(tier: .initiate, size: 82, letterFallback: "U", shopBorder: border)
            }
        case .rankBanner(let tier):
            ShopBackdropArtworkPreview(
                assetName: RankCosmetics.profileHeaderBannerAsset(for: tier.rankTitle),
                accent: tier.rewardTint,
                role: .profileBanner,
                symbolName: nil,
                isMuted: !state.isUnlockedOrOwned,
                scrimOpacity: 0.30
            )
        case .shopBanner(let item):
            ShopBackdropArtworkPreview(
                assetName: item.backdropAssetName,
                accent: item.accent,
                role: .profileBanner,
                symbolName: nil,
                isMuted: !state.isUnlockedOrOwned,
                scrimOpacity: 0.30
            )
        }
    }

    private struct PreviewShape: ViewModifier {
        let isBanner: Bool
        func body(content: Content) -> some View {
            if isBanner {
                content.aspectRatio(16.0 / 9.0, contentMode: .fit)
            } else {
                content.frame(height: 132)
            }
        }
    }

    // MARK: Info

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.title)
                .font(Font.unbound.bodyMStrong)
                .foregroundStyle(state.isUnlockedOrOwned ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.66)

            HStack(spacing: 6) {
                Label(row.typeTitle.uppercased(), systemImage: row.systemImage)
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(row.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
                Text(row.detail.uppercased())
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stateBadge: some View {
        Text(state.statusTitle.uppercased())
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(badgeForeground)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(badgeBackground))
            .overlay(Capsule().strokeBorder(badgeForeground.opacity(0.28), lineWidth: 0.75))
    }

    private var badgeBackground: Color {
        if state.isSelected { return Color.unbound.rankGold.opacity(0.22) }
        if state.isUnlockedOrOwned { return Color.unbound.bg.opacity(0.78) }
        return Color.unbound.bg.opacity(0.72)
    }

    private var badgeForeground: Color {
        if state.isSelected { return Color.unbound.rankGold }
        if state.isUnlockedOrOwned { return Color.unbound.textSecondary }
        return Color.unbound.textTertiary
    }
}
