import Foundation

enum ShopPurchaseResult: Equatable {
    case purchased
    case alreadyOwned
    case insufficientFunds(shortfall: Int)
}

final class CurrencyWalletStore: ObservableObject {
    static let shared = CurrencyWalletStore(backup: RewardsCloudBackup.shared)

    private static let balanceKeyPrefix = "unbound.wallet.vows."
    private static let grantLedgerKeyPrefix = "unbound.wallet.vows.grantLedger."
    #if DEBUG
    private static let debugUnlimitedBalance = 9_999_999
    private static let devAccountModeKey = "unbound.dev.accountMode"
    private static let freshLoginDevAccountMode = "fresh-login"
    #endif

    private let defaults: UserDefaults
    /// Optional cloud mirror. The production `.shared` store wires the real
    /// backup; test-constructed stores get `nil` so unit tests never touch
    /// the outbox / SyncedDatabase. Local UserDefaults stays the source of
    /// truth. Dev-credit short-circuits never fire it — a dev-inflated wallet
    /// must not be mirrored.
    private let backup: (any RewardsBackuping)?
    private var userId = "anonymous"

    @Published private(set) var balance: Int = 0

    init(defaults: UserDefaults = .standard, backup: (any RewardsBackuping)? = nil) {
        self.defaults = defaults
        self.backup = backup
    }

    func bind(userId: String) {
        self.userId = userId
        if Self.usesUnlimitedDevCredits(userId, defaults: defaults) {
            balance = Self.debugBalance
            persistStoredBalanceWithoutBroadcast()
            return
        }
        // Arcs are earn-only: there is no starter grant. A new wallet begins at 0
        // and every Arc is earned through training, vows, and squad rewards.
        balance = defaults.integer(forKey: Self.balanceKeyPrefix + userId)
    }

    func canAfford(_ amount: Int) -> Bool {
        if Self.usesUnlimitedDevCredits(userId, defaults: defaults) { return true }
        return balance >= max(0, amount)
    }

    @discardableResult
    func spend(_ amount: Int) -> Bool {
        let price = max(0, amount)
        if Self.usesUnlimitedDevCredits(userId, defaults: defaults) {
            restoreDebugBalance()
            return true
        }
        guard balance >= price else { return false }
        balance -= price
        persist()
        backup?.backup(userId: userId)
        return true
    }

    func grant(_ amount: Int) {
        let reward = max(0, amount)
        guard reward > 0 else { return }
        if Self.usesUnlimitedDevCredits(userId, defaults: defaults) {
            restoreDebugBalance()
            return
        }
        balance += reward
        persist()
        backup?.backup(userId: userId)
    }

    func hasGranted(sourceId: String) -> Bool {
        let ledger = Set(defaults.stringArray(forKey: Self.grantLedgerKeyPrefix + userId) ?? [])
        return ledger.contains(sourceId)
    }

    @discardableResult
    func grant(_ amount: Int, sourceId: String) -> Bool {
        let reward = max(0, amount)
        guard reward > 0 else { return false }

        var ledger = Set(defaults.stringArray(forKey: Self.grantLedgerKeyPrefix + userId) ?? [])
        guard !ledger.contains(sourceId) else {
            if Self.usesUnlimitedDevCredits(userId, defaults: defaults) { restoreDebugBalance() }
            return false
        }
        ledger.insert(sourceId)
        defaults.set(ledger.sorted(), forKey: Self.grantLedgerKeyPrefix + userId)

        if Self.usesUnlimitedDevCredits(userId, defaults: defaults) {
            restoreDebugBalance()
            return true
        }
        balance += reward
        persist()
        backup?.backup(userId: userId)
        return true
    }

    static func storedBalance(userId: String, defaults: UserDefaults = .standard) -> Int {
        if usesUnlimitedDevCredits(userId, defaults: defaults) { return debugBalance }
        return defaults.integer(forKey: balanceKeyPrefix + userId)
    }

    // MARK: - Cloud backup seams

    /// Raw persisted values for `RewardsCloudBackup`. Unlike `storedBalance`,
    /// these deliberately bypass the DEBUG unlimited-credits short-circuit —
    /// a dev-inflated read must never be mirrored to the cloud.
    static func persistedBalance(userId: String, defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: balanceKeyPrefix + userId)
    }

    static func persistedGrantLedger(userId: String, defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: grantLedgerKeyPrefix + userId) ?? [])
    }

    /// Restore-path writes (cloud seed only). Statics on purpose: the seed
    /// merges into the given user's keys and rebinds any live instance
    /// afterward so `@Published` state refreshes.
    static func restorePersisted(balance: Int, userId: String, defaults: UserDefaults = .standard) {
        defaults.set(balance, forKey: balanceKeyPrefix + userId)
        NotificationCenter.default.post(name: .vowsBalanceChanged, object: nil)
    }

    static func restorePersisted(grantLedger: Set<String>, userId: String, defaults: UserDefaults = .standard) {
        defaults.set(grantLedger.sorted(), forKey: grantLedgerKeyPrefix + userId)
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

    private static func usesUnlimitedDevCredits(_ userId: String, defaults: UserDefaults) -> Bool {
        #if DEBUG
        if defaults.string(forKey: devAccountModeKey) == freshLoginDevAccountMode {
            return false
        }
        return userId == "dev-player" || userId.hasPrefix("dev-player-")
        #else
        return false
        #endif
    }
}

final class ShopInventoryStore: ObservableObject {
    static let shared = ShopInventoryStore(backup: RewardsCloudBackup.shared)

    private static let purchasedKeyPrefix = "unbound.shop.inventory."
    private static let equippedHomeBackgroundKeyPrefix = "unbound.shop.equippedHomeBackground."
    private static let equippedHomeBackdropKeyPrefix = "unbound.shop.equippedBackdrop.home."
    private static let equippedBorderKeyPrefix = "unbound.shop.equippedProfileBorder."
    private static let equippedBackgroundKeyPrefix = "unbound.shop.equippedProfileBackground."
    private static let equippedProfileBackdropKeyPrefix = "unbound.shop.equippedBackdrop.profile."

    private let defaults: UserDefaults
    /// Optional cloud mirror (see `CurrencyWalletStore.backup`). Fired after
    /// purchases and equip changes; the snapshot is full-state, so a hook that
    /// follows a guard-rejected no-op collapses in the redundant-patch cache.
    private let backup: (any RewardsBackuping)?
    private var userId = "anonymous"

    @Published private(set) var purchasedItemIDs: Set<String> = []

    init(defaults: UserDefaults = .standard, backup: (any RewardsBackuping)? = nil) {
        self.defaults = defaults
        self.backup = backup
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
        backup?.backup(userId: userId)
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
        backup?.backup(userId: userId)
    }

    func clearEquippedHomeBackground() {
        Self.clearEquippedHomeBackground(userId: userId, defaults: defaults)
        backup?.backup(userId: userId)
    }

    func setEquippedProfileBorder(_ border: ShopProfileBorderID) {
        Self.setEquippedProfileBorder(border, userId: userId, defaults: defaults)
        backup?.backup(userId: userId)
    }

    func clearEquippedProfileBorder() {
        Self.clearEquippedProfileBorder(userId: userId, defaults: defaults)
        backup?.backup(userId: userId)
    }

    func setEquippedProfileBackground(_ background: ShopProfileBackgroundID) {
        Self.setEquippedProfileBackground(background, userId: userId, defaults: defaults)
        backup?.backup(userId: userId)
    }

    func setEquippedBackdrop(_ item: ShopItem, for surface: ShopBackdropSurface) {
        Self.setEquippedBackdrop(item, for: surface, userId: userId, defaults: defaults)
        backup?.backup(userId: userId)
    }

    func clearEquippedProfileBackground() {
        Self.clearEquippedProfileBackground(userId: userId, defaults: defaults)
        backup?.backup(userId: userId)
    }

    func clearEquippedBackdrop(for surface: ShopBackdropSurface) {
        Self.clearEquippedBackdrop(for: surface, userId: userId, defaults: defaults)
        backup?.backup(userId: userId)
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

    // MARK: - Cloud backup seams

    /// Raw persisted equip-slot values (no ownership filtering): the cloud
    /// backup mirrors exactly what is stored, and the ownership guard
    /// re-applies through the setters on restore.
    struct EquippedSlotSnapshot: Equatable {
        var homeBackground: String?
        var homeBackdrop: String?
        var profileBorder: String?
        var profileBackground: String?
        var profileBackdrop: String?

        func backdropItemId(for surface: ShopBackdropSurface) -> String? {
            switch surface {
            case .home:
                return homeBackdrop
            case .profile:
                return profileBackdrop
            }
        }
    }

    static func equippedSlotSnapshot(userId: String, defaults: UserDefaults = .standard) -> EquippedSlotSnapshot {
        EquippedSlotSnapshot(
            homeBackground: defaults.string(forKey: equippedHomeBackgroundKeyPrefix + userId),
            homeBackdrop: defaults.string(forKey: equippedHomeBackdropKeyPrefix + userId),
            profileBorder: defaults.string(forKey: equippedBorderKeyPrefix + userId),
            profileBackground: defaults.string(forKey: equippedBackgroundKeyPrefix + userId),
            profileBackdrop: defaults.string(forKey: equippedProfileBackdropKeyPrefix + userId)
        )
    }

    /// Union cloud-restored purchase ids into the persisted set (purchases
    /// are permanent). Ids missing from the current catalog are kept verbatim
    /// so a backup written by a newer build never loses items. Returns the
    /// ids that were newly added.
    @discardableResult
    static func restorePurchased(_ ids: Set<String>, userId: String, defaults: UserDefaults = .standard) -> Set<String> {
        let existing = purchasedItemIDs(userId: userId, defaults: defaults)
        let added = ids.subtracting(existing)
        guard !added.isEmpty else { return [] }
        persist(existing.union(added), userId: userId, defaults: defaults)
        NotificationCenter.default.post(name: .shopInventoryChanged, object: nil)
        return added
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
