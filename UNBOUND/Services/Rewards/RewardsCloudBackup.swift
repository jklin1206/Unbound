import Foundation

/// Cloud mirror for the currency wallet, shop inventory, and cosmetic
/// preferences.
///
/// The Arcs balance, its grant ledger, PURCHASED shop items, the equipped
/// cosmetic slots, and the profile showcase / skin preferences all live in
/// device UserDefaults; without a cloud copy a reinstall silently wipes them —
/// including purchases the user paid earned currency for. This service patches
/// one full snapshot onto the synced `users` doc through the SAME offline-safe
/// choke point every other users-doc write takes (`SyncedDatabase` -> outbox
/// -> `sync_merge_row` field-level merge), so an offline write is retried by
/// the outbox and a concurrent edit to another column of the row survives.
/// Local UserDefaults stays the source of truth; this is a best-effort mirror
/// whose failures are logged, never silenced.
protocol RewardsBackuping: Sendable {
    func backup(userId: String)
}

/// The wire payload for the `users.rewardsBackup` field: the wallet, the shop
/// inventory, and the cosmetic preferences as ONE jsonb value so the balance
/// and the purchases it paid for can never drift apart across two partially
/// applied patches.
///
/// Everything rides as raw persisted values (`rawValue` strings / Int tiers),
/// never resolved models: the restore side re-applies the same ownership and
/// unlock guards the live setters enforce, so a payload written by a build
/// with a different catalog can never equip something the user does not own.
struct RewardsBackup: Codable, Equatable, Sendable {
    struct Wallet: Codable, Equatable, Sendable {
        /// The raw persisted balance — never the DEBUG unlimited-credits read.
        var balance: Int = 0
        /// Earn-event source ids. Unioned on restore so a restored event can
        /// never re-credit.
        var grantLedger: [String] = []
    }

    struct Shop: Codable, Equatable, Sendable {
        var purchased: [String] = []
        /// The five raw equip-slot values (`ShopInventoryStore`'s keys).
        var equippedHomeBackground: String?
        var equippedHomeBackdrop: String?
        var equippedProfileBorder: String?
        var equippedProfileBackground: String?
        var equippedProfileBackdrop: String?
    }

    struct Showcase: Codable, Equatable, Sendable {
        var skillId: String?
        var liftId: String?
    }

    struct Cosmetics: Codable, Equatable, Sendable {
        /// Highest rank-cosmetic tier ever reached (`RankTier` rawValue).
        /// Recomputable from rank progress, but cheap to carry — max-merged.
        var highestTier: Int?
        var frameTier: Int?
        var backgroundTier: Int?
        var showcase: Showcase?
        /// `SkillTreeSkin` rawValue of the chosen skin; unlocked skins are NOT
        /// carried (recomputable from rank + the restored purchases).
        var currentSkin: String?
    }

    var wallet: Wallet
    var shop: Shop
    var cosmetics: Cosmetics
}

final class RewardsCloudBackup: RewardsBackuping, @unchecked Sendable {
    static let shared = RewardsCloudBackup()

    private let database: any DatabaseServiceProtocol
    private let logger: LoggingService
    private let defaults: UserDefaults

    /// Serializes the patch writes AND guards `lastSent`: each backup call
    /// captures its snapshot synchronously and chains behind the previous
    /// write, so a rapid spend -> purchase pair can never land out of order
    /// and let a stale snapshot overwrite a newer one (locally or via the
    /// FIFO outbox).
    private let tailLock = NSLock()
    private var tail: Task<Void, Never>?
    /// Last successfully patched snapshot per userId. Equip taps that the
    /// ownership guard rejected (and any other no-op save) produce an
    /// identical snapshot and skip the redundant patch.
    private var lastSent: [String: RewardsBackup] = [:]

    /// ISO-8601 dates to match both `DatabaseService` (local decode) and
    /// `UnboundSupabase.dbDecoder` (remote decode). The payload carries no
    /// dates today; keeping the strategy means adding one later cannot fork
    /// the round-trip.
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(
        database: any DatabaseServiceProtocol = SyncedDatabase.shared,
        logger: LoggingService = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.database = database
        self.logger = logger
        self.defaults = defaults
    }

    // MARK: - Write path

    /// Snapshot every store from its persisted keys (never from live
    /// instances, so this is callable from any thread) and enqueue the patch.
    func backup(userId: String) {
        enqueuePatch(snapshot(userId: userId), userId: userId)
    }

    /// Internal (not private) so the sign-in identity migration
    /// (`ProductionUserDataMigrationRewardsStore`) can read both users' raw
    /// persisted state through the SAME snapshot this backup mirrors.
    func snapshot(userId: String) -> RewardsBackup {
        let slots = ShopInventoryStore.equippedSlotSnapshot(userId: userId, defaults: defaults)
        let showcase = ProfileShowcaseStore.load(userId: userId, defaults: defaults)
        return RewardsBackup(
            wallet: RewardsBackup.Wallet(
                balance: CurrencyWalletStore.persistedBalance(userId: userId, defaults: defaults),
                grantLedger: CurrencyWalletStore.persistedGrantLedger(userId: userId, defaults: defaults).sorted()
            ),
            shop: RewardsBackup.Shop(
                purchased: ShopInventoryStore.purchasedItemIDs(userId: userId, defaults: defaults).sorted(),
                equippedHomeBackground: slots.homeBackground,
                equippedHomeBackdrop: slots.homeBackdrop,
                equippedProfileBorder: slots.profileBorder,
                equippedProfileBackground: slots.profileBackground,
                equippedProfileBackdrop: slots.profileBackdrop
            ),
            cosmetics: RewardsBackup.Cosmetics(
                highestTier: RankCosmetics.persistedHighestTierRawValue(userId: userId, defaults: defaults),
                frameTier: RankCosmetics.persistedEquippedFrameTier(userId: userId, defaults: defaults)?.rawValue,
                backgroundTier: RankCosmetics.persistedEquippedBackgroundTier(userId: userId, defaults: defaults)?.rawValue,
                showcase: showcase == .empty
                    ? nil
                    : RewardsBackup.Showcase(skillId: showcase.skillId, liftId: showcase.liftId),
                currentSkin: SkinService.persistedCurrentSkinRawValue(defaults: defaults)
            )
        )
    }

    /// Append this snapshot to the ordered write chain. The snapshot is taken
    /// at call time; the chain guarantees write order matches call order.
    private func enqueuePatch(_ snapshot: RewardsBackup, userId: String) {
        tailLock.lock()
        defer { tailLock.unlock() }
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            await self?.patch(snapshot, userId: userId)
        }
    }

    /// Patch the backup field onto the `users` doc. `id` travels in the
    /// payload (the `sync_merge_row` ownership guard reads `p_full->>'id'`,
    /// and it is excluded from the SET clause server-side) so the write is
    /// valid even if this device has no local `users` doc yet.
    /// Lock use lives in synchronous helpers: NSLock is not async-safe to
    /// hold across awaits, and Swift 6 rejects lock()/unlock() in async code.
    private func isAlreadySent(_ snapshot: RewardsBackup, userId: String) -> Bool {
        tailLock.lock()
        defer { tailLock.unlock() }
        return lastSent[userId] == snapshot
    }

    private func markSent(_ snapshot: RewardsBackup, userId: String) {
        tailLock.lock()
        defer { tailLock.unlock() }
        lastSent[userId] = snapshot
    }

    private func patch(_ snapshot: RewardsBackup, userId: String) async {
        // Compared at patch time (the chain is serialized), so a burst of
        // saves that changed nothing durable collapses to zero patches.
        guard !isAlreadySent(snapshot, userId: userId) else { return }

        guard let encoded = Self.jsonObject(snapshot) else {
            logger.log(
                "Rewards cloud backup: failed to encode snapshot",
                level: .error,
                context: ["userId": userId]
            )
            return
        }
        do {
            try await database.update(
                ["id": userId, "rewardsBackup": encoded],
                collection: "users",
                documentId: userId
            )
            markSent(snapshot, userId: userId)
        } catch {
            // lastSent stays untouched so the next durable save retries.
            logger.log(
                "Rewards cloud backup failed: \(error)",
                level: .error,
                context: ["userId": userId]
            )
        }
    }

    // MARK: - Restore path

    /// Seed the local stores from a fetched server profile. Merge semantics,
    /// in restore order:
    ///
    /// 1. Wallet — the balance is NEVER max-merged (that would refund spent
    ///    Arcs). It is adopted only into a completely empty wallet (balance 0
    ///    AND empty grant ledger — a fresh install); otherwise local stands.
    ///    The grant ledger unions both ways so a restored earn-event can never
    ///    re-credit.
    /// 2. Purchases — set union (purchases are permanent). Unknown ids are
    ///    kept verbatim so a payload from a newer catalog never loses items.
    ///    Shop-exclusive skin unlocks are re-derived from the restored items.
    /// 3. Equipped slots — restored ONLY after the purchases above, through
    ///    the same ownership-guarded setters the live UI uses (an equip whose
    ///    item is not owned is dropped). Adopt-when-local-unset; a local
    ///    choice always wins.
    /// 4. Rank cosmetics — highest tier max-merges; equipped frame/background
    ///    tiers adopt-when-unset behind the (just-merged) unlock guard.
    /// 5. Showcase / current skin — adopt-when-unset preferences.
    ///
    /// Writes happen only when something actually changes; seeding never fires
    /// a cloud write of its own. Safe to run every launch.
    @MainActor
    func seedLocalStores(
        from profile: UserProfile,
        userId: String,
        wallet: CurrencyWalletStore = .shared,
        inventory: ShopInventoryStore = .shared,
        skinService: SkinService? = nil,
        defaults: UserDefaults = .standard
    ) {
        guard let cloud = profile.rewardsBackup else { return }
        seedLocalStores(
            from: cloud,
            userId: userId,
            wallet: wallet,
            inventory: inventory,
            skinService: skinService,
            defaults: defaults
        )
    }

    // `skinService` is nil-defaulted (not `= .shared`) because SkinService is
    // MainActor-isolated and default-argument expressions are checked as
    // nonisolated; the body resolves it under this function's @MainActor.
    @MainActor
    func seedLocalStores(
        from cloud: RewardsBackup,
        userId: String,
        wallet: CurrencyWalletStore = .shared,
        inventory: ShopInventoryStore = .shared,
        skinService: SkinService? = nil,
        defaults: UserDefaults = .standard
    ) {
        let skinService = skinService ?? .shared
        let walletChanged = seedWallet(cloud.wallet, userId: userId, defaults: defaults)

        // Purchases BEFORE equips: the equip setters are ownership-guarded and
        // would drop a restored equip whose item is not yet owned.
        let restoredItemIds = ShopInventoryStore.restorePurchased(
            Set(cloud.shop.purchased),
            userId: userId,
            defaults: defaults
        )
        unlockRestoredSkins(restoredItemIds, skinService: skinService)
        seedEquippedSlots(cloud.shop, userId: userId, defaults: defaults)

        seedRankCosmetics(cloud.cosmetics, userId: userId, defaults: defaults)
        seedShowcase(cloud.cosmetics.showcase, userId: userId, defaults: defaults)
        seedCurrentSkin(cloud.cosmetics.currentSkin, skinService: skinService, defaults: defaults)

        // Rebind so already-live @Published state reflects the restored keys.
        if walletChanged {
            wallet.bind(userId: userId)
        }
        if !restoredItemIds.isEmpty {
            inventory.bind(userId: userId)
        }
    }

    // MARK: - Restore steps

    private func seedWallet(_ cloud: RewardsBackup.Wallet, userId: String, defaults: UserDefaults) -> Bool {
        var changed = false
        let localBalance = CurrencyWalletStore.persistedBalance(userId: userId, defaults: defaults)
        let localLedger = CurrencyWalletStore.persistedGrantLedger(userId: userId, defaults: defaults)

        // A zero balance with a non-empty ledger is a spent-down wallet, not
        // an empty one — adopting the cloud balance there would refund Arcs.
        if localBalance == 0, localLedger.isEmpty, cloud.balance > 0 {
            CurrencyWalletStore.restorePersisted(balance: cloud.balance, userId: userId, defaults: defaults)
            changed = true
        }

        let mergedLedger = localLedger.union(cloud.grantLedger)
        if mergedLedger != localLedger {
            CurrencyWalletStore.restorePersisted(grantLedger: mergedLedger, userId: userId, defaults: defaults)
            changed = true
        }
        return changed
    }

    /// Re-derive the unlocks a purchase implies, for the restored items only.
    /// Deliberately NOT `ShopInventoryStore.applyReward`: that path also
    /// re-grants profile titles into `WeeklyVowsStore`, whose cloud restore is
    /// `AchievementsCloudBackup`'s job — seeding must not cross-write another
    /// backup's store (or fire its unlock toasts) during launch. Skin unlocks
    /// have no other restore home, so they are re-derived here.
    @MainActor
    private func unlockRestoredSkins(_ itemIds: Set<String>, skinService: SkinService) {
        for id in itemIds.sorted() {
            guard let item = ShopCatalog.item(id: id),
                  case .skillTreeSkin(let skin) = item.reward
            else { continue }
            skinService.unlockPurchasedSkin(skin)
        }
    }

    @MainActor
    private func seedEquippedSlots(_ cloud: RewardsBackup.Shop, userId: String, defaults: UserDefaults) {
        let local = ShopInventoryStore.equippedSlotSnapshot(userId: userId, defaults: defaults)

        // Background setters write their paired backdrop key too, so adopting
        // one requires BOTH of the surface's slots to be locally unset — a
        // local cross-surface backdrop choice must never be clobbered.
        if local.homeBackground == nil, local.homeBackdrop == nil,
           let background = cloud.equippedHomeBackground.flatMap(ShopHomeBackgroundID.init(rawValue:)) {
            ShopInventoryStore.setEquippedHomeBackground(background, userId: userId, defaults: defaults)
        }
        if local.profileBackground == nil, local.profileBackdrop == nil,
           let background = cloud.equippedProfileBackground.flatMap(ShopProfileBackgroundID.init(rawValue:)) {
            ShopInventoryStore.setEquippedProfileBackground(background, userId: userId, defaults: defaults)
        }
        if local.profileBorder == nil,
           let border = cloud.equippedProfileBorder.flatMap(ShopProfileBorderID.init(rawValue:)) {
            ShopInventoryStore.setEquippedProfileBorder(border, userId: userId, defaults: defaults)
        }
        // Backdrop slots AFTER the backgrounds: a background restore writes
        // its paired backdrop key, so only a differing cloud value (a
        // cross-surface equip) still needs to land.
        restoreBackdropSlot(
            cloud.equippedHomeBackdrop,
            surface: .home,
            wasLocallySet: local.homeBackdrop != nil,
            userId: userId,
            defaults: defaults
        )
        restoreBackdropSlot(
            cloud.equippedProfileBackdrop,
            surface: .profile,
            wasLocallySet: local.profileBackdrop != nil,
            userId: userId,
            defaults: defaults
        )
    }

    @MainActor
    private func restoreBackdropSlot(
        _ cloudItemId: String?,
        surface: ShopBackdropSurface,
        wasLocallySet: Bool,
        userId: String,
        defaults: UserDefaults
    ) {
        guard !wasLocallySet,
              let cloudItemId,
              ShopInventoryStore.equippedSlotSnapshot(userId: userId, defaults: defaults)
                  .backdropItemId(for: surface) != cloudItemId,
              let item = ShopCatalog.item(id: cloudItemId)
        else { return }
        ShopInventoryStore.setEquippedBackdrop(item, for: surface, userId: userId, defaults: defaults)
    }

    private func seedRankCosmetics(_ cloud: RewardsBackup.Cosmetics, userId: String, defaults: UserDefaults) {
        if let cloudHighest = cloud.highestTier.flatMap(SkillTier.init(rawValue:)),
           cloudHighest.rawValue > (RankCosmetics.persistedHighestTierRawValue(userId: userId, defaults: defaults) ?? Int.min) {
            _ = RankCosmetics.recordUnlockedTier(userId: userId, currentTier: cloudHighest, defaults: defaults)
        }
        // Equipped tiers restore AFTER the highest-tier merge above: the
        // setters re-apply the unlock guard (tier must be <= highest).
        if RankCosmetics.persistedEquippedFrameTier(userId: userId, defaults: defaults) == nil,
           let tier = cloud.frameTier.flatMap(SkillTier.init(rawValue:)) {
            RankCosmetics.setEquippedFrameTier(tier, userId: userId, currentTier: .initiate, defaults: defaults)
        }
        if RankCosmetics.persistedEquippedBackgroundTier(userId: userId, defaults: defaults) == nil,
           let tier = cloud.backgroundTier.flatMap(SkillTier.init(rawValue:)) {
            RankCosmetics.setEquippedBackgroundTier(tier, userId: userId, currentTier: .initiate, defaults: defaults)
        }
    }

    private func seedShowcase(_ cloud: RewardsBackup.Showcase?, userId: String, defaults: UserDefaults) {
        guard let cloud,
              cloud.skillId != nil || cloud.liftId != nil,
              ProfileShowcaseStore.load(userId: userId, defaults: defaults) == .empty
        else { return }
        ProfileShowcaseStore.save(
            ProfileShowcaseSelection(skillId: cloud.skillId, liftId: cloud.liftId),
            userId: userId,
            defaults: defaults
        )
    }

    @MainActor
    private func seedCurrentSkin(_ cloudRawValue: String?, skinService: SkinService, defaults: UserDefaults) {
        guard SkinService.persistedCurrentSkinRawValue(defaults: defaults) == nil,
              let skin = cloudRawValue.flatMap(SkillTreeSkin.init(rawValue:)),
              skin != skinService.currentSkin
        else { return }
        // setCurrent enforces the unlock guard; a rank-gated skin that has not
        // re-unlocked yet is skipped (evaluateUnlocks recomputes it later).
        try? skinService.setCurrent(skin)
    }

    // MARK: - Helpers

    /// Encode a Codable value to a Foundation JSON object (`[String: Any]`) so it
    /// can ride inside the `[String: Any]` field dict `DatabaseService.update`
    /// serializes with `JSONSerialization`.
    private static func jsonObject<T: Encodable>(_ value: T) -> Any? {
        guard let data = try? encoder.encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
