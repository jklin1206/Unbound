import SwiftUI

struct BackdropPickerView: View {
    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    @StateObject private var inventory = ShopInventoryStore.shared
    @State private var selectedSurface: ShopBackdropSurface
    @State private var equippedHomeBackdrop: ShopItem?
    @State private var equippedProfileBackdrop: ShopItem?

    private let openShop: (() -> Void)?
    private let columns = [
        GridItem(.adaptive(minimum: 142), spacing: 12)
    ]

    init(initialSurface: ShopBackdropSurface = .home, openShop: (() -> Void)? = nil) {
        self.openShop = openShop
        _selectedSurface = State(initialValue: initialSurface)
    }

    private var userId: String {
        services.auth.currentUserId ?? "anonymous"
    }

    private var visibleItems: [ShopItem] {
        ShopCatalog.items(for: .backdrop).filter { item in
            switch (selectedSurface, item.reward) {
            case (.home, .homeBackground), (.profile, .profileBackground):
                return true
            default:
                return false
            }
        }
    }

    private var ownedVisibleCount: Int {
        visibleItems.filter { inventory.isPurchased($0) }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                surfacePicker
                defaultTile

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleItems) { item in
                        BackdropPickerTile(
                            title: item.name,
                            eyebrow: inventory.isPurchased(item) ? item.rarity : "Shop",
                            assetName: assetName(for: item),
                            accent: item.accent,
                            eyebrowTint: inventory.isPurchased(item) ? item.rarityTint : nil,
                            isSelected: isEquipped(item),
                            isLocked: !inventory.isPurchased(item),
                            actionTitle: actionTitle(for: item)
                        ) {
                            primaryAction(for: item)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Backdrops")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            inventory.bind(userId: userId)
            refreshEquippedState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shopInventoryChanged)) { _ in
            refreshEquippedState()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.skinHex("5EEAD4"), Color.skinHex("F6C95B"), Color.skinHex("FF4FD8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: selectedSurface.systemImage)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.74))
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(selectedSurface.displayName.uppercased()) BACKDROP")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(activeBackdropName)
                    .font(Font.unbound.titleS)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            Text("\(ownedVisibleCount)/\(visibleItems.count)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.unbound.rankGold)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(Color.unbound.rankGold.opacity(0.14)))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.92))
        )
    }

    private var surfacePicker: some View {
        Picker("Surface", selection: $selectedSurface) {
            ForEach(ShopBackdropSurface.allCases) { surface in
                Label(surface.displayName, systemImage: surface.systemImage)
                    .tag(surface)
            }
        }
        .pickerStyle(.segmented)
    }

    private var defaultTile: some View {
        BackdropPickerTile(
            title: defaultBackdropName,
            eyebrow: "Default",
            assetName: defaultAssetName,
            accent: defaultAccent,
            eyebrowTint: nil,
            isSelected: isDefaultSelected,
            isLocked: false,
            actionTitle: isDefaultSelected ? "Active" : "Use"
        ) {
            equipDefault()
        }
    }

    private var defaultBackdropName: String {
        switch selectedSurface {
        case .home: return "Chalk Chamber"
        case .profile: return "Rank Backdrop"
        }
    }

    private var defaultAssetName: String? {
        switch selectedSurface {
        case .home:
            return "home_background_chalk"
        case .profile:
            return RankCosmetics.profileBackgroundAsset(for: .initiate)
        }
    }

    private var defaultAccent: Color {
        switch selectedSurface {
        case .home: return Color.skinHex("2DD4BF")
        case .profile: return SkillTier.initiate.rewardTint
        }
    }

    private var isDefaultSelected: Bool {
        activeBackdrop == nil
    }

    private var activeBackdropName: String {
        activeBackdrop?.name ?? defaultBackdropName
    }

    private var activeBackdrop: ShopItem? {
        switch selectedSurface {
        case .home:
            return equippedHomeBackdrop
        case .profile:
            return equippedProfileBackdrop
        }
    }

    @MainActor
    private func primaryAction(for item: ShopItem) {
        guard inventory.isPurchased(item) else {
            openShop?()
            return
        }

        inventory.setEquippedBackdrop(item, for: selectedSurface)

        refreshEquippedState()
        UnboundHaptics.soft()
    }

    @MainActor
    private func equipDefault() {
        switch selectedSurface {
        case .home:
            inventory.clearEquippedBackdrop(for: .home)
        case .profile:
            inventory.clearEquippedBackdrop(for: .profile)
        }
        refreshEquippedState()
        UnboundHaptics.soft()
    }

    @MainActor
    private func refreshEquippedState() {
        equippedHomeBackdrop = inventory.equippedBackdrop(for: .home)
        equippedProfileBackdrop = inventory.equippedBackdrop(for: .profile)
    }

    private func isEquipped(_ item: ShopItem) -> Bool {
        activeBackdrop?.id == item.id
    }

    private func assetName(for item: ShopItem) -> String? {
        item.backdropAssetName
    }

    private func actionTitle(for item: ShopItem) -> String {
        if isEquipped(item) { return "Active" }
        if inventory.isPurchased(item) { return "Use" }
        return "Shop"
    }
}

struct BackdropPickerTile: View {
    let title: String
    let eyebrow: String
    let assetName: String?
    let accent: Color
    let eyebrowTint: Color?
    let isSelected: Bool
    let isLocked: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                preview
                    .aspectRatio(ShopBackdropArtworkPreview.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isSelected ? accent.opacity(0.92) : Color.unbound.borderSubtle, lineWidth: isSelected ? 1.8 : 1)
                    )

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(eyebrow.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(isLocked ? Color.unbound.textTertiary : (eyebrowTint ?? accent))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(title)
                            .font(Font.unbound.bodyMStrong)
                            .foregroundStyle(isLocked ? Color.unbound.textSecondary : Color.unbound.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.68)
                            .frame(minHeight: 38, alignment: .topLeading)
                    }

                    Spacer(minLength: 0)

                    Text(actionTitle.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(actionForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .frame(width: 58, height: 28)
                        .background(Capsule().fill(actionBackground))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.unbound.surface.opacity(isSelected ? 0.96 : 0.86))
            )
            .opacity(isLocked ? 0.62 : 1)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.unbound.rankGold)
                        .padding(9)
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color.unbound.textTertiary)
                        .padding(10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var preview: some View {
        ShopBackdropArtworkPreview(
            assetName: assetName,
            accent: accent,
            isMuted: isLocked
        )
    }

    private var actionBackground: Color {
        if isSelected { return Color.unbound.rankGold.opacity(0.18) }
        if isLocked { return Color.unbound.surfaceElevated }
        return accent.opacity(0.22)
    }

    private var actionForeground: Color {
        if isSelected { return Color.unbound.rankGold }
        return isLocked ? Color.unbound.textTertiary : Color.unbound.textPrimary
    }
}
