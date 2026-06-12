import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    @StateObject private var wallet = CurrencyWalletStore.shared
    @StateObject private var inventory = ShopInventoryStore.shared

    @State private var selectedCategory: ShopCategory = .backdrop
    @State private var equippedTitle: TitleID?
    @State private var equippedHomeBackdrop: ShopItem?
    @State private var equippedProfileBorder: ShopProfileBorderID?
    @State private var equippedProfileBackdrop: ShopItem?
    @State private var previewedSkillTreeSkin: SkillTreeSkin = .chalk
    @State private var message: String?

    private let itemColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    private let categoryColumns = [
        GridItem(.adaptive(minimum: 104), spacing: 8)
    ]

    init(initialCategory: ShopCategory = .backdrop) {
        _selectedCategory = State(initialValue: initialCategory)
    }

    private var userId: String {
        services.auth.currentUserId ?? "anonymous"
    }

    private var visibleItems: [ShopItem] {
        ShopCatalog.items(for: selectedCategory)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                categoryRail

                if selectedCategory == .skillTree {
                    skillTreeShowcase
                }

                LazyVGrid(columns: itemColumns, spacing: 12) {
                    ForEach(visibleItems) { item in
                        ShopItemCard(
                            item: item,
                            isOwned: inventory.isPurchased(item),
                            isEquipped: isEquipped(item),
                            canAfford: wallet.canAfford(item.price),
                            actionTitle: actionTitle(for: item),
                            action: { primaryAction(for: item) }
                        )
                    }
                }

                Spacer(minLength: 18)
            }
            .padding(20)
        }
        .background(Color.unbound.bg.ignoresSafeArea())
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .overlay(alignment: .bottom) {
            if let message {
                Text(message.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Capsule().fill(Color.unbound.surfaceElevated))
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .shopInventoryChanged)) { _ in
            refreshEquippedState()
            if selectedCategory == .skillTree {
                syncPreviewedSkillTreeSkin()
            }
        }
        .onChange(of: selectedCategory) { _, category in
            if category == .skillTree {
                syncPreviewedSkillTreeSkin()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.unbound.impact.opacity(0.13))
                    Image("shop_currency_arc")
                        .resizable()
                        .scaledToFit()
                        .padding(3)
                        .shadow(color: Color.unbound.impact.opacity(0.30), radius: 7)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("BALANCE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(Color.unbound.textTertiary)
                    ArcCurrencyAmount(
                        amount: wallet.balance,
                        label: nil,
                        iconSize: 22,
                        spacing: 6,
                        iconPlacement: .trailing,
                        valueFont: .system(size: 28, weight: .black, design: .rounded),
                        valueColor: Color.unbound.textPrimary
                    )
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(inventory.purchasedItemIDs.count)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.unbound.rankGold)
                    Text("OWNED")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(Color.unbound.textTertiary)
                }
            }

            if let message {
                Text(message)
                    .font(Font.unbound.captionS.weight(.semibold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.unbound.surface)
        )
    }

    private var categoryRail: some View {
        LazyVGrid(columns: categoryColumns, spacing: 8) {
            ForEach(ShopCategory.allCases) { category in
                Button {
                    UnboundHaptics.soft()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedCategory = category
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: category.systemImage)
                            .font(.system(size: 11, weight: .black))
                        Text(category.displayName.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .allowsTightening(true)
                    }
                    .foregroundStyle(selectedCategory == category ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(selectedCategory == category ? Color.unbound.accent.opacity(0.30) : Color.unbound.surface.opacity(0.82))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var skillTreeShowcase: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TREE SKIN")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(previewedSkillTreeSkin.displayName.uppercased())
                        .font(Font.unbound.titleS)
                        .tracking(1.0)
                        .foregroundStyle(Color.unbound.textPrimary)
                }

                Spacer(minLength: 0)

                if SkinService.shared.currentSkin == previewedSkillTreeSkin {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(previewedSkillTreeSkin.impactColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(previewedSkillTreeSkin.impactColor.opacity(0.16)))
                }
            }

            ShopSkillTreeMapPreview(skin: previewedSkillTreeSkin, compact: false)
                .frame(height: 270)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(previewedSkillTreeSkin.primaryColor.opacity(0.34), lineWidth: 1)
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShopCatalog.items(for: .skillTree)) { item in
                        if case .skillTreeSkin(let skin) = item.reward {
                            Button {
                                UnboundHaptics.soft()
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    previewedSkillTreeSkin = skin
                                }
                            } label: {
                                Text(item.name.uppercased())
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .tracking(0.7)
                                    .foregroundStyle(previewedSkillTreeSkin == skin ? Color.unbound.textPrimary : Color.unbound.textSecondary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .frame(height: 30)
                                    .background(
                                        Capsule()
                                            .fill(previewedSkillTreeSkin == skin ? skin.primaryColor.opacity(0.22) : Color.unbound.surfaceElevated.opacity(0.82))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(previewedSkillTreeSkin == skin ? skin.primaryColor.opacity(0.72) : Color.unbound.borderSubtle, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.unbound.surface.opacity(0.88))
        )
        .shadow(color: previewedSkillTreeSkin.primaryColor.opacity(0.10), radius: 16, y: 8)
    }

    @MainActor
    private func load() async {
        wallet.bind(userId: userId)
        inventory.bind(userId: userId)
        refreshEquippedState()
        syncPreviewedSkillTreeSkin()
    }

    @MainActor
    private func primaryAction(for item: ShopItem) {
        if inventory.isPurchased(item) {
            equip(item)
            return
        }

        switch inventory.purchase(item, wallet: wallet) {
        case .purchased:
            equip(item)
            showMessage("\(item.name) purchased and equipped.")
            UnboundHaptics.success()
        case .alreadyOwned:
            equip(item)
        case .insufficientFunds(let shortfall):
            showMessage("Need \(shortfall) more.")
            UnboundHaptics.medium()
        }
    }

    @MainActor
    private func equip(_ item: ShopItem) {
        switch item.reward {
        case .homeBackground(let background):
            inventory.setEquippedHomeBackground(background)
        case .skillTreeSkin(let skin):
            SkinService.shared.unlockPurchasedSkin(skin)
            try? SkinService.shared.setCurrent(skin)
            previewedSkillTreeSkin = skin
        case .profileBorder(let border):
            inventory.setEquippedProfileBorder(border)
        case .profileBackground(let background):
            inventory.setEquippedProfileBackground(background)
        case .profileTitle(let titleID):
            services.trials.equipTitle(titleID, userId: userId)
        }
        refreshEquippedState()
    }

    @MainActor
    private func refreshEquippedState() {
        equippedTitle = services.trials.state(userId: userId).equippedTitle
        equippedHomeBackdrop = inventory.equippedBackdrop(for: .home)
        equippedProfileBorder = inventory.equippedProfileBorder()
        equippedProfileBackdrop = inventory.equippedBackdrop(for: .profile)
    }

    private func actionTitle(for item: ShopItem) -> String {
        if isEquipped(item) { return "Equipped" }
        if inventory.isPurchased(item) { return "Equip" }
        if wallet.canAfford(item.price) { return "Buy" }
        return "Need \(max(0, item.price - wallet.balance))"
    }

    private func isEquipped(_ item: ShopItem) -> Bool {
        switch item.reward {
        case .homeBackground:
            return equippedHomeBackdrop?.id == item.id
        case .skillTreeSkin(let skin):
            return SkinService.shared.currentSkin == skin
        case .profileBorder(let border):
            return equippedProfileBorder == border
        case .profileBackground:
            return equippedProfileBackdrop?.id == item.id
        case .profileTitle(let titleID):
            return equippedTitle == titleID
        }
    }

    private func syncPreviewedSkillTreeSkin() {
        guard selectedCategory == .skillTree else { return }
        let current = SkinService.shared.currentSkin
        if ShopCatalog.item(for: .skillTreeSkin(current)) != nil {
            previewedSkillTreeSkin = current
        }
    }

    private func showMessage(_ text: String) {
        withAnimation(.easeInOut(duration: 0.18)) {
            message = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.easeInOut(duration: 0.18)) {
                if message == text {
                    message = nil
                }
            }
        }
    }
}
