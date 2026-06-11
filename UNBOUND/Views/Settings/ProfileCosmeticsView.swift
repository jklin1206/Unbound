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
                cosmeticTable
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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
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
                .foregroundStyle(Color.unbound.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cosmeticTable: some View {
        VStack(spacing: 0) {
            ForEach(profileRows) { row in
                ProfileCosmeticTableRow(
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
        let confirmedRank = OverallRankTrialStore.shared.load(userId: userId).currentRank
        currentTier = RankCosmetics.equipped(highestRank: confirmedRank)
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

    private func actionTitle(for row: ProfileCosmeticRow) -> String {
        if isSelected(row) { return "Active" }
        if isUnlockedOrOwned(row) { return "Use" }
        return row.isShopItem && openShop != nil ? "Shop" : "Locked"
    }

    private var activeCosmeticSummary: String {
        let frame = equippedShopProfileBorder?.displayName ?? equippedFrameTier.displayName
        let banner = activeShopBanner?.name ?? equippedBackgroundTier.displayName
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
            return "\(tier.displayName) Banner"
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

private struct ProfileCosmeticTableRow: View {
    let row: ProfileCosmeticRow
    let state: ProfileCosmeticOptionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                preview
                    .frame(width: previewSize.width, height: previewSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(state.isSelected ? row.accent.opacity(0.92) : Color.unbound.borderSubtle, lineWidth: state.isSelected ? 1.8 : 1)
                    )
                    .saturation(state.isUnlockedOrOwned ? 1 : 0.16)
                    .opacity(state.isUnlockedOrOwned ? 1 : 0.52)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Label(row.typeTitle.uppercased(), systemImage: row.systemImage)
                            .labelStyle(.titleAndIcon)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(row.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)

                        Text(row.sourceTitle.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(Color.unbound.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                    }

                    Text(row.title)
                        .font(Font.unbound.bodyMStrong)
                        .foregroundStyle(state.isUnlockedOrOwned ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    Text(row.detail.uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(statusTint)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Text(state.actionTitle.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(actionForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.54)
                    .frame(width: 58, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(state.isSelected ? row.accent.opacity(0.10) : Color.clear)
            .overlay(alignment: .bottom) {
                UnboundNativeDivider(opacity: 0.34)
                    .padding(.leading, previewSize.width + 24)
            }
        }
        .buttonStyle(.plain)
        .disabled(state.isActionDisabled)
    }

    private var previewSize: CGSize {
        switch row {
        case .rankBanner, .shopBanner:
            return CGSize(width: 72, height: 52)
        case .rankFrame, .shopBorder:
            return CGSize(width: 58, height: 58)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch row {
        case .rankFrame(let tier):
            ZStack {
                Color.unbound.bg
                CosmeticAvatar(tier: tier.rankTitle, size: 52, letterFallback: "U")
            }
        case .rankBanner(let tier):
            ShopBackdropArtworkPreview(
                assetName: RankCosmetics.profileBackgroundAsset(for: tier.rankTitle),
                accent: tier.rewardTint,
                role: .profileBanner,
                symbolName: nil,
                isMuted: !state.isUnlockedOrOwned,
                scrimOpacity: 0.34
            )
        case .shopBorder(let item):
            ZStack {
                LinearGradient(
                    colors: item.colors.map { $0.opacity(0.82) } + [Color.unbound.surfaceElevated],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if case .profileBorder(let border) = item.reward {
                    Circle()
                        .fill(Color.unbound.bg.opacity(0.82))
                        .frame(width: 34, height: 34)
                    if let ui = UIImage(named: border.assetName) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                    } else {
                        Circle()
                            .strokeBorder(border.accent, lineWidth: 5)
                            .frame(width: 44, height: 44)
                    }
                }
            }
        case .shopBanner(let item):
            ShopBackdropArtworkPreview(
                assetName: item.backdropAssetName,
                accent: item.accent,
                role: .profileBanner,
                symbolName: nil,
                isMuted: !state.isUnlockedOrOwned,
                scrimOpacity: 0.34
            )
        }
    }

    private var statusTint: Color {
        if state.isSelected { return Color.unbound.rankGold }
        return state.isUnlockedOrOwned ? row.accent : Color.unbound.textTertiary
    }

    private var actionForeground: Color {
        if state.isSelected { return Color.unbound.rankGold }
        if state.isUnlockedOrOwned { return Color.unbound.accent }
        return Color.unbound.textTertiary
    }
}
