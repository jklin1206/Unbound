import Foundation

enum ShopPurchaseResult: Equatable {
    case purchased
    case alreadyOwned
    case insufficientFunds(shortfall: Int)
}

final class CurrencyWalletStore: ObservableObject {
    static let shared = CurrencyWalletStore()

    private static let balanceKeyPrefix = "unbound.wallet.vows."
    private static let starterGrantKeyPrefix = "unbound.wallet.vows.starterGrant."
    private static let grantLedgerKeyPrefix = "unbound.wallet.vows.grantLedger."
    private static let starterGrant = 1_500
    #if DEBUG
    private static let debugUnlimitedBalance = 9_999_999
    private static let devAccountModeKey = "unbound.dev.accountMode"
    private static let freshLoginDevAccountMode = "fresh-login"
    #endif

    private let defaults: UserDefaults
    private var userId = "anonymous"

    @Published private(set) var balance: Int = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func bind(userId: String) {
        self.userId = userId
        if Self.usesUnlimitedDevCredits(userId) {
            balance = Self.debugBalance
            persistStoredBalanceWithoutBroadcast()
            defaults.set(true, forKey: Self.starterGrantKeyPrefix + userId)
            return
        }
        if !defaults.bool(forKey: Self.starterGrantKeyPrefix + userId) {
            defaults.set(Self.starterGrant, forKey: Self.balanceKeyPrefix + userId)
            defaults.set(true, forKey: Self.starterGrantKeyPrefix + userId)
        }
        balance = defaults.integer(forKey: Self.balanceKeyPrefix + userId)
    }

    func canAfford(_ amount: Int) -> Bool {
        if Self.usesUnlimitedDevCredits(userId) { return true }
        return balance >= max(0, amount)
    }

    @discardableResult
    func spend(_ amount: Int) -> Bool {
        let price = max(0, amount)
        if Self.usesUnlimitedDevCredits(userId) {
            restoreDebugBalance()
            return true
        }
        guard balance >= price else { return false }
        balance -= price
        persist()
        return true
    }

    func grant(_ amount: Int) {
        let reward = max(0, amount)
        guard reward > 0 else { return }
        if Self.usesUnlimitedDevCredits(userId) {
            restoreDebugBalance()
            return
        }
        balance += reward
        persist()
    }

    @discardableResult
    func grant(_ amount: Int, sourceId: String) -> Bool {
        let reward = max(0, amount)
        guard reward > 0 else { return false }

        var ledger = Set(defaults.stringArray(forKey: Self.grantLedgerKeyPrefix + userId) ?? [])
        guard !ledger.contains(sourceId) else {
            if Self.usesUnlimitedDevCredits(userId) { restoreDebugBalance() }
            return false
        }
        ledger.insert(sourceId)
        defaults.set(ledger.sorted(), forKey: Self.grantLedgerKeyPrefix + userId)

        if Self.usesUnlimitedDevCredits(userId) {
            restoreDebugBalance()
            return true
        }
        balance += reward
        persist()
        return true
    }

    static func storedBalance(userId: String, defaults: UserDefaults = .standard) -> Int {
        if usesUnlimitedDevCredits(userId) { return debugBalance }
        return defaults.integer(forKey: balanceKeyPrefix + userId)
    }

    private func persist() {
        defaults.set(balance, forKey: Self.balanceKeyPrefix + userId)
        NotificationCenter.default.post(name: .vowsBalanceChanged, object: nil)
    }

    private func restoreDebugBalance() {
        balance = Self.debugBalance
        persist()
    }

    private func persistStoredBalanceWithoutBroadcast() {
        defaults.set(balance, forKey: Self.balanceKeyPrefix + userId)
    }

    private static var debugBalance: Int {
        #if DEBUG
        return debugUnlimitedBalance
        #else
        return 0
        #endif
    }

    private static func usesUnlimitedDevCredits(_ userId: String) -> Bool {
        #if DEBUG
        if UserDefaults.standard.string(forKey: devAccountModeKey) == freshLoginDevAccountMode {
            return false
        }
        return userId == "dev-player" || userId.hasPrefix("dev-player-")
        #else
        return false
        #endif
    }
}

final class ShopInventoryStore: ObservableObject {
    static let shared = ShopInventoryStore()

    private static let purchasedKeyPrefix = "unbound.shop.inventory."
    private static let equippedHomeBackgroundKeyPrefix = "unbound.shop.equippedHomeBackground."
    private static let equippedHomeBackdropKeyPrefix = "unbound.shop.equippedBackdrop.home."
    private static let equippedBorderKeyPrefix = "unbound.shop.equippedProfileBorder."
    private static let equippedBackgroundKeyPrefix = "unbound.shop.equippedProfileBackground."
    private static let equippedProfileBackdropKeyPrefix = "unbound.shop.equippedBackdrop.profile."

    private let defaults: UserDefaults
    private var userId = "anonymous"

    @Published private(set) var purchasedItemIDs: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func bind(userId: String) {
        self.userId = userId
        purchasedItemIDs = Self.purchasedItemIDs(userId: userId, defaults: defaults)
    }

    func isPurchased(_ item: ShopItem) -> Bool {
        purchasedItemIDs.contains(item.id)
    }

    @MainActor
    @discardableResult
    func purchase(_ item: ShopItem, wallet: CurrencyWalletStore) -> ShopPurchaseResult {
        if isPurchased(item) { return .alreadyOwned }
        guard wallet.spend(item.price) else {
            return .insufficientFunds(shortfall: max(0, item.price - wallet.balance))
        }

        purchasedItemIDs.insert(item.id)
        Self.persist(purchasedItemIDs, userId: userId, defaults: defaults)
        applyReward(item)
        NotificationCenter.default.post(name: .shopInventoryChanged, object: item)
        return .purchased
    }

    static func purchasedItemIDs(userId: String, defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: purchasedKeyPrefix + userId) ?? [])
    }

    static func markPurchased(_ item: ShopItem, userId: String, defaults: UserDefaults = .standard) {
        var ids = purchasedItemIDs(userId: userId, defaults: defaults)
        ids.insert(item.id)
        persist(ids, userId: userId, defaults: defaults)
    }

    static func hasPurchased(itemID: String, userId: String, defaults: UserDefaults = .standard) -> Bool {
        purchasedItemIDs(userId: userId, defaults: defaults).contains(itemID)
    }

    static func purchasedSkillTreeSkins(userId: String, defaults: UserDefaults = .standard) -> Set<SkillTreeSkin> {
        rewards(userId: userId, defaults: defaults).reduce(into: []) { result, reward in
            if case .skillTreeSkin(let skin) = reward {
                result.insert(skin)
            }
        }
    }

    static func purchasedHomeBackgrounds(userId: String, defaults: UserDefaults = .standard) -> Set<ShopHomeBackgroundID> {
        rewards(userId: userId, defaults: defaults).reduce(into: []) { result, reward in
            if case .homeBackground(let background) = reward {
                result.insert(background)
            }
        }
    }

    static func purchasedProfileTitles(userId: String, defaults: UserDefaults = .standard) -> Set<TitleID> {
        rewards(userId: userId, defaults: defaults).reduce(into: []) { result, reward in
            if case .profileTitle(let titleID) = reward {
                result.insert(titleID)
            }
        }
    }

    static func purchasedProfileBorders(userId: String, defaults: UserDefaults = .standard) -> Set<ShopProfileBorderID> {
        rewards(userId: userId, defaults: defaults).reduce(into: []) { result, reward in
            if case .profileBorder(let border) = reward {
                result.insert(border)
            }
        }
    }

    static func purchasedProfileBackgrounds(userId: String, defaults: UserDefaults = .standard) -> Set<ShopProfileBackgroundID> {
        rewards(userId: userId, defaults: defaults).reduce(into: []) { result, reward in
            if case .profileBackground(let background) = reward {
                result.insert(background)
            }
        }
    }

    func equippedProfileBorder() -> ShopProfileBorderID? {
        Self.equippedProfileBorder(userId: userId, defaults: defaults)
    }

    func equippedHomeBackground() -> ShopHomeBackgroundID? {
        Self.equippedHomeBackground(userId: userId, defaults: defaults)
    }

    func equippedProfileBackground() -> ShopProfileBackgroundID? {
        Self.equippedProfileBackground(userId: userId, defaults: defaults)
    }

    func equippedBackdrop(for surface: ShopBackdropSurface) -> ShopItem? {
        Self.equippedBackdrop(for: surface, userId: userId, defaults: defaults)
    }

    func setEquippedHomeBackground(_ background: ShopHomeBackgroundID) {
        Self.setEquippedHomeBackground(background, userId: userId, defaults: defaults)
    }

    func clearEquippedHomeBackground() {
        Self.clearEquippedHomeBackground(userId: userId, defaults: defaults)
    }

    func setEquippedProfileBorder(_ border: ShopProfileBorderID) {
        Self.setEquippedProfileBorder(border, userId: userId, defaults: defaults)
    }

    func clearEquippedProfileBorder() {
        Self.clearEquippedProfileBorder(userId: userId, defaults: defaults)
    }

    func setEquippedProfileBackground(_ background: ShopProfileBackgroundID) {
        Self.setEquippedProfileBackground(background, userId: userId, defaults: defaults)
    }

    func setEquippedBackdrop(_ item: ShopItem, for surface: ShopBackdropSurface) {
        Self.setEquippedBackdrop(item, for: surface, userId: userId, defaults: defaults)
    }

    func clearEquippedProfileBackground() {
        Self.clearEquippedProfileBackground(userId: userId, defaults: defaults)
    }

    func clearEquippedBackdrop(for surface: ShopBackdropSurface) {
        Self.clearEquippedBackdrop(for: surface, userId: userId, defaults: defaults)
    }

    static func equippedProfileBorder(userId: String, defaults: UserDefaults = .standard) -> ShopProfileBorderID? {
        guard let raw = defaults.string(forKey: equippedBorderKeyPrefix + userId),
              let border = ShopProfileBorderID(rawValue: raw),
              purchasedProfileBorders(userId: userId, defaults: defaults).contains(border)
        else { return nil }
        return border
    }

    static func equippedHomeBackground(userId: String, defaults: UserDefaults = .standard) -> ShopHomeBackgroundID? {
        guard let raw = defaults.string(forKey: equippedHomeBackgroundKeyPrefix + userId),
              let background = ShopHomeBackgroundID(rawValue: raw),
              purchasedHomeBackgrounds(userId: userId, defaults: defaults).contains(background)
        else { return nil }
        return background
    }

    static func equippedProfileBackground(userId: String, defaults: UserDefaults = .standard) -> ShopProfileBackgroundID? {
        guard let raw = defaults.string(forKey: equippedBackgroundKeyPrefix + userId),
              let background = ShopProfileBackgroundID(rawValue: raw),
              purchasedProfileBackgrounds(userId: userId, defaults: defaults).contains(background)
        else { return nil }
        return background
    }

    static func equippedBackdrop(
        for surface: ShopBackdropSurface,
        userId: String,
        defaults: UserDefaults = .standard
    ) -> ShopItem? {
        if let itemID = defaults.string(forKey: equippedBackdropKeyPrefix(for: surface) + userId),
           let item = ShopCatalog.item(id: itemID),
           item.isBackdrop,
           hasPurchased(itemID: item.id, userId: userId, defaults: defaults) {
            return item
        }

        switch surface {
        case .home:
            guard let background = equippedHomeBackground(userId: userId, defaults: defaults) else { return nil }
            return ShopCatalog.item(for: .homeBackground(background))
        case .profile:
            guard let background = equippedProfileBackground(userId: userId, defaults: defaults) else { return nil }
            return ShopCatalog.item(for: .profileBackground(background))
        }
    }

    static func setEquippedProfileBorder(
        _ border: ShopProfileBorderID,
        userId: String,
        defaults: UserDefaults = .standard
    ) {
        guard let item = ShopCatalog.item(for: .profileBorder(border)),
              hasPurchased(itemID: item.id, userId: userId, defaults: defaults)
        else { return }
        defaults.set(border.rawValue, forKey: equippedBorderKeyPrefix + userId)
        NotificationCenter.default.post(name: .shopInventoryChanged, object: item)
    }

    static func clearEquippedProfileBorder(userId: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: equippedBorderKeyPrefix + userId)
        NotificationCenter.default.post(name: .shopInventoryChanged, object: nil)
    }

    static func setEquippedHomeBackground(
        _ background: ShopHomeBackgroundID,
        userId: String,
        defaults: UserDefaults = .standard
    ) {
        guard let item = ShopCatalog.item(for: .homeBackground(background)),
              hasPurchased(itemID: item.id, userId: userId, defaults: defaults)
        else { return }
        defaults.set(background.rawValue, forKey: equippedHomeBackgroundKeyPrefix + userId)
        defaults.set(item.id, forKey: equippedHomeBackdropKeyPrefix + userId)
        NotificationCenter.default.post(name: .shopInventoryChanged, object: item)
    }

    static func clearEquippedHomeBackground(userId: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: equippedHomeBackgroundKeyPrefix + userId)
        defaults.removeObject(forKey: equippedHomeBackdropKeyPrefix + userId)
        NotificationCenter.default.post(name: .shopInventoryChanged, object: nil)
    }

    static func setEquippedProfileBackground(
        _ background: ShopProfileBackgroundID,
        userId: String,
        defaults: UserDefaults = .standard
    ) {
        guard let item = ShopCatalog.item(for: .profileBackground(background)),
              hasPurchased(itemID: item.id, userId: userId, defaults: defaults)
        else { return }
        defaults.set(background.rawValue, forKey: equippedBackgroundKeyPrefix + userId)
        defaults.set(item.id, forKey: equippedProfileBackdropKeyPrefix + userId)
        NotificationCenter.default.post(name: .shopInventoryChanged, object: item)
    }

    static func setEquippedBackdrop(
        _ item: ShopItem,
        for surface: ShopBackdropSurface,
        userId: String,
        defaults: UserDefaults = .standard
    ) {
        guard item.isBackdrop,
              hasPurchased(itemID: item.id, userId: userId, defaults: defaults)
        else { return }

        switch (surface, item.reward) {
        case (.home, .homeBackground(let background)):
            setEquippedHomeBackground(background, userId: userId, defaults: defaults)
        case (.profile, .profileBackground(let background)):
            setEquippedProfileBackground(background, userId: userId, defaults: defaults)
        default:
            defaults.set(item.id, forKey: equippedBackdropKeyPrefix(for: surface) + userId)
            NotificationCenter.default.post(name: .shopInventoryChanged, object: item)
        }
    }

    static func clearEquippedProfileBackground(userId: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: equippedBackgroundKeyPrefix + userId)
        defaults.removeObject(forKey: equippedProfileBackdropKeyPrefix + userId)
        NotificationCenter.default.post(name: .shopInventoryChanged, object: nil)
    }

    static func clearEquippedBackdrop(
        for surface: ShopBackdropSurface,
        userId: String,
        defaults: UserDefaults = .standard
    ) {
        defaults.removeObject(forKey: equippedBackdropKeyPrefix(for: surface) + userId)
        switch surface {
        case .home:
            defaults.removeObject(forKey: equippedHomeBackgroundKeyPrefix + userId)
        case .profile:
            defaults.removeObject(forKey: equippedBackgroundKeyPrefix + userId)
        }
        NotificationCenter.default.post(name: .shopInventoryChanged, object: nil)
    }

    private static func equippedBackdropKeyPrefix(for surface: ShopBackdropSurface) -> String {
        switch surface {
        case .home:
            return equippedHomeBackdropKeyPrefix
        case .profile:
            return equippedProfileBackdropKeyPrefix
        }
    }

    private static func rewards(userId: String, defaults: UserDefaults) -> [ShopItemReward] {
        let ids = purchasedItemIDs(userId: userId, defaults: defaults)
        return ShopCatalog.items.compactMap { ids.contains($0.id) ? $0.reward : nil }
    }

    private static func persist(_ ids: Set<String>, userId: String, defaults: UserDefaults) {
        defaults.set(ids.sorted(), forKey: purchasedKeyPrefix + userId)
    }

    @MainActor
    private func applyReward(_ item: ShopItem) {
        switch item.reward {
        case .homeBackground:
            break
        case .skillTreeSkin(let skin):
            SkinService.shared.unlockPurchasedSkin(skin)
        case .profileBorder, .profileBackground:
            break
        case .profileTitle(let titleID):
            var state = WeeklyVowsStore.shared.load(userId: userId)
            if !state.unlockedTitles.contains(titleID) {
                state.unlockedTitles.append(titleID)
                WeeklyVowsStore.shared.save(state, userId: userId)
                NotificationCenter.default.post(name: .titleUnlocked, object: titleID)
            }
        }
    }
}

extension Notification.Name {
    static let vowsBalanceChanged = Notification.Name("unbound.vowsBalanceChanged")
    static let shopInventoryChanged = Notification.Name("unbound.shopInventoryChanged")
}
