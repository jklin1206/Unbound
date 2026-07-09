import XCTest
@testable import UNBOUND

/// Covers the cloud mirror for the currency wallet, shop inventory, and
/// cosmetic preferences: the ordered users-doc patch under `rewardsBackup`
/// (raw stored values, redundant-patch skip) and the restore-side merge —
/// wallet adopt-only-into-empty + ledger union, purchase union, equips
/// restored only after ownership, adopt-when-unset preferences, and the
/// highest-cosmetic-tier max.
@MainActor
final class RewardsCloudBackupTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var spy: SpyDatabase!
    private var backup: RewardsCloudBackup!
    private let userId = "u1"

    override func setUp() {
        super.setUp()
        suiteName = "RewardsCloudBackupTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        spy = SpyDatabase()
        backup = RewardsCloudBackup(database: spy, defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Fixtures

    /// Stores are constructed WITHOUT a backup seam: fixture writes and
    /// seeding must never fire a cloud write of their own.
    private func makeWallet() -> CurrencyWalletStore {
        let wallet = CurrencyWalletStore(defaults: defaults)
        wallet.bind(userId: userId)
        return wallet
    }

    private func makeInventory() -> ShopInventoryStore {
        let inventory = ShopInventoryStore(defaults: defaults)
        inventory.bind(userId: userId)
        return inventory
    }

    private func cloudBackup(
        wallet: RewardsBackup.Wallet = RewardsBackup.Wallet(),
        shop: RewardsBackup.Shop = RewardsBackup.Shop(),
        cosmetics: RewardsBackup.Cosmetics = RewardsBackup.Cosmetics()
    ) -> RewardsBackup {
        RewardsBackup(wallet: wallet, shop: shop, cosmetics: cosmetics)
    }

    private func seed(
        _ cloud: RewardsBackup,
        wallet: CurrencyWalletStore? = nil,
        inventory: ShopInventoryStore? = nil,
        skins: SkinService? = nil
    ) {
        backup.seedLocalStores(
            from: cloud,
            userId: userId,
            wallet: wallet ?? makeWallet(),
            inventory: inventory ?? makeInventory(),
            skinService: skins ?? SkinService(defaults: defaults),
            defaults: defaults
        )
    }

    /// Decode the patched jsonb payload with the same conventions
    /// `UnboundSupabase.dbDecoder` applies to production reads, proving the
    /// backup round-trips through the remote decode path.
    nonisolated private func decodedPayload(_ update: SpyDatabase.Update) throws -> RewardsBackup {
        let object = try XCTUnwrap(update.fields["rewardsBackup"])
        let data = try JSONSerialization.data(withJSONObject: object)
        return try UnboundSupabase.dbDecoder.decode(RewardsBackup.self, from: data)
    }

    // MARK: - (a) users-doc patch shape from stored values

    func test_backup_patches_users_doc_under_rewardsBackup_with_stored_state() async throws {
        let wallet = makeWallet()
        XCTAssertTrue(wallet.grant(500, sourceId: "vow:s1"))
        XCTAssertTrue(wallet.spend(200))

        let borderItem = ShopCatalog.item(id: "profileBorder.tapeWrap")!
        ShopInventoryStore.markPurchased(borderItem, userId: userId, defaults: defaults)
        ShopInventoryStore.setEquippedProfileBorder(.tapeWrap, userId: userId, defaults: defaults)

        _ = RankCosmetics.recordUnlockedTier(userId: userId, currentTier: .veteran, defaults: defaults)
        RankCosmetics.setEquippedFrameTier(.novice, userId: userId, currentTier: .veteran, defaults: defaults)
        ProfileShowcaseStore.save(
            ProfileShowcaseSelection(skillId: "pull-up", liftId: nil),
            userId: userId,
            defaults: defaults
        )
        try SkinService(defaults: defaults).setCurrent(.graphite)

        backup.backup(userId: userId)

        let updates = await spy.waitForUpdates(count: 1)
        let update = try XCTUnwrap(updates.first)
        XCTAssertEqual(update.collection, "users")
        XCTAssertEqual(update.documentId, userId)
        XCTAssertEqual(update.fields["id"] as? String, userId, "id must travel in the payload for the sync_merge_row ownership guard")

        let payload = try decodedPayload(update)
        XCTAssertEqual(payload.wallet.balance, 300)
        XCTAssertEqual(payload.wallet.grantLedger, ["vow:s1"])
        XCTAssertEqual(payload.shop.purchased, [borderItem.id])
        XCTAssertEqual(payload.shop.equippedProfileBorder, ShopProfileBorderID.tapeWrap.rawValue)
        XCTAssertNil(payload.shop.equippedHomeBackground)
        XCTAssertEqual(payload.cosmetics.highestTier, SkillTier.veteran.rawValue)
        XCTAssertEqual(payload.cosmetics.frameTier, SkillTier.novice.rawValue)
        XCTAssertNil(payload.cosmetics.backgroundTier)
        XCTAssertEqual(payload.cosmetics.showcase, RewardsBackup.Showcase(skillId: "pull-up", liftId: nil))
        XCTAssertEqual(payload.cosmetics.currentSkin, SkillTreeSkin.graphite.rawValue)
    }

    func test_backup_captures_stored_balance_never_the_dev_inflated_read() async throws {
        #if DEBUG
        XCTAssertGreaterThanOrEqual(
            CurrencyWalletStore.storedBalance(userId: "dev-player", defaults: defaults),
            9_000_000,
            "premise: the live read IS dev-inflated for dev accounts"
        )
        #endif

        backup.backup(userId: "dev-player")

        let updates = await spy.waitForUpdates(count: 1)
        let update = try XCTUnwrap(updates.first)
        XCTAssertEqual(
            try decodedPayload(update).wallet.balance,
            0,
            "the mirror must carry the raw persisted balance, not the DEBUG unlimited-credits read"
        )
    }

    // MARK: - (b) wallet restore

    func test_wallet_restore_adopts_cloud_only_into_an_empty_wallet() async {
        let wallet = makeWallet()

        seed(cloudBackup(wallet: RewardsBackup.Wallet(balance: 500, grantLedger: ["vow:s1"])), wallet: wallet)

        XCTAssertEqual(CurrencyWalletStore.persistedBalance(userId: userId, defaults: defaults), 500)
        XCTAssertEqual(wallet.balance, 500, "the live wallet rebinds to the restored balance")
        XCTAssertTrue(wallet.hasGranted(sourceId: "vow:s1"))
        let updateCount = await spy.updates.count
        XCTAssertEqual(updateCount, 0, "seeding must never fire a cloud write of its own")
    }

    func test_wallet_restore_never_refunds_a_spent_down_balance() {
        let wallet = makeWallet()
        wallet.grant(500, sourceId: "vow:s1")
        XCTAssertTrue(wallet.spend(450))

        seed(cloudBackup(wallet: RewardsBackup.Wallet(balance: 500, grantLedger: ["vow:s1"])), wallet: wallet)
        XCTAssertEqual(wallet.balance, 50, "a cloud copy must never refund spent Arcs")

        // Fully spent down is still not "empty": the ledger proves history.
        XCTAssertTrue(wallet.spend(50))
        seed(cloudBackup(wallet: RewardsBackup.Wallet(balance: 500, grantLedger: ["vow:s1"])), wallet: wallet)
        XCTAssertEqual(wallet.balance, 0, "a zero balance with a non-empty ledger keeps local")
    }

    func test_wallet_ledger_unions_so_restored_earn_events_cannot_recredit() {
        let wallet = makeWallet()
        wallet.grant(100, sourceId: "vow:local")
        XCTAssertTrue(wallet.spend(100))

        seed(cloudBackup(wallet: RewardsBackup.Wallet(balance: 900, grantLedger: ["vow:cloud"])), wallet: wallet)

        XCTAssertEqual(wallet.balance, 0, "a non-empty local wallet keeps its balance")
        XCTAssertEqual(
            CurrencyWalletStore.persistedGrantLedger(userId: userId, defaults: defaults),
            ["vow:local", "vow:cloud"]
        )
        XCTAssertFalse(wallet.grant(50, sourceId: "vow:cloud"), "a restored earn-event must not re-credit")
        XCTAssertEqual(wallet.balance, 0)
    }

    // MARK: - (c) purchases union

    func test_purchases_union_and_refresh_the_live_inventory() {
        let inventory = makeInventory()
        let localItem = ShopCatalog.item(id: "homeBackground.chamber")!
        ShopInventoryStore.markPurchased(localItem, userId: userId, defaults: defaults)

        seed(cloudBackup(shop: RewardsBackup.Shop(purchased: ["profileBorder.tapeWrap"])), inventory: inventory)

        let expected: Set<String> = [localItem.id, "profileBorder.tapeWrap"]
        XCTAssertEqual(ShopInventoryStore.purchasedItemIDs(userId: userId, defaults: defaults), expected)
        XCTAssertEqual(inventory.purchasedItemIDs, expected, "the live inventory rebinds to the union")
    }

    // MARK: - (d) equips restore only after ownership

    func test_equips_restore_after_purchases_so_the_ownership_guard_keeps_them() {
        let cloud = cloudBackup(shop: RewardsBackup.Shop(
            purchased: ["profileBorder.tapeWrap", "homeBackground.chamber", "skillTreeSkin.glassCircuit"],
            equippedHomeBackground: ShopHomeBackgroundID.chamber.rawValue,
            equippedHomeBackdrop: "homeBackground.chamber",
            equippedProfileBorder: ShopProfileBorderID.tapeWrap.rawValue
        ))
        let skins = SkinService(defaults: defaults)

        seed(cloud, skins: skins)

        // The guarded getters only return an equip whose item is owned, so a
        // non-nil read proves purchases landed before the equip slots.
        XCTAssertEqual(ShopInventoryStore.equippedProfileBorder(userId: userId, defaults: defaults), .tapeWrap)
        XCTAssertEqual(ShopInventoryStore.equippedHomeBackground(userId: userId, defaults: defaults), .chamber)
        XCTAssertEqual(
            ShopInventoryStore.equippedBackdrop(for: .home, userId: userId, defaults: defaults)?.id,
            "homeBackground.chamber"
        )
        XCTAssertTrue(
            skins.unlockedSkins.contains(.glassCircuit),
            "restored purchases re-derive shop-exclusive skin unlocks"
        )
    }

    // MARK: - (e) adopt only when locally unset

    func test_equipped_slots_adopt_only_when_locally_unset() {
        ShopInventoryStore.markPurchased(
            ShopCatalog.item(id: "profileBorder.bronzeRivets")!,
            userId: userId,
            defaults: defaults
        )
        ShopInventoryStore.setEquippedProfileBorder(.bronzeRivets, userId: userId, defaults: defaults)

        seed(cloudBackup(shop: RewardsBackup.Shop(
            purchased: ["profileBorder.tapeWrap"],
            equippedProfileBorder: ShopProfileBorderID.tapeWrap.rawValue
        )))

        XCTAssertEqual(
            ShopInventoryStore.equippedProfileBorder(userId: userId, defaults: defaults),
            .bronzeRivets,
            "a local equip choice wins over the cloud copy"
        )
    }

    func test_showcase_and_skin_adopt_only_when_locally_unset() {
        let skins = SkinService(defaults: defaults)

        // Unset local: adopt the cloud preferences.
        seed(cloudBackup(cosmetics: RewardsBackup.Cosmetics(
            showcase: RewardsBackup.Showcase(skillId: "pull-up", liftId: nil),
            currentSkin: SkillTreeSkin.graphite.rawValue
        )), skins: skins)
        XCTAssertEqual(ProfileShowcaseStore.load(userId: userId, defaults: defaults).skillId, "pull-up")
        XCTAssertEqual(skins.currentSkin, .graphite)

        // Set local: keep it.
        ProfileShowcaseStore.save(
            ProfileShowcaseSelection(skillId: "front-lever", liftId: nil),
            userId: userId,
            defaults: defaults
        )
        seed(cloudBackup(cosmetics: RewardsBackup.Cosmetics(
            showcase: RewardsBackup.Showcase(skillId: "planche", liftId: nil),
            currentSkin: SkillTreeSkin.violet.rawValue
        )), skins: skins)
        XCTAssertEqual(ProfileShowcaseStore.load(userId: userId, defaults: defaults).skillId, "front-lever")
        XCTAssertEqual(skins.currentSkin, .graphite, "a chosen skin is never overwritten by the cloud copy")
    }

    func test_locked_cloud_skin_is_skipped_not_force_unlocked() {
        let skins = SkinService(defaults: defaults)

        // glassCircuit is shop-exclusive and NOT among the restored purchases.
        seed(cloudBackup(cosmetics: RewardsBackup.Cosmetics(
            currentSkin: SkillTreeSkin.glassCircuit.rawValue
        )), skins: skins)

        XCTAssertEqual(skins.currentSkin, .violet, "a still-locked skin cannot be adopted; evaluateUnlocks recomputes later")
        XCTAssertNil(SkinService.persistedCurrentSkinRawValue(defaults: defaults))
    }

    func test_rank_cosmetic_equip_tiers_adopt_only_when_unset_behind_the_unlock_guard() {
        // Unset local, tier unlocked by the merged highest: adopt.
        seed(cloudBackup(cosmetics: RewardsBackup.Cosmetics(
            highestTier: SkillTier.veteran.rawValue,
            frameTier: SkillTier.forged.rawValue
        )))
        XCTAssertEqual(RankCosmetics.persistedEquippedFrameTier(userId: userId, defaults: defaults), .forged)

        // Locally chosen: the cloud copy must not override.
        RankCosmetics.setEquippedFrameTier(.novice, userId: userId, currentTier: .veteran, defaults: defaults)
        seed(cloudBackup(cosmetics: RewardsBackup.Cosmetics(
            highestTier: SkillTier.veteran.rawValue,
            frameTier: SkillTier.veteran.rawValue
        )))
        XCTAssertEqual(RankCosmetics.persistedEquippedFrameTier(userId: userId, defaults: defaults), .novice)
    }

    // MARK: - (f) redundant identical backup skips the patch

    func test_redundant_identical_backup_skips_the_patch() async throws {
        let wallet = makeWallet()
        wallet.grant(100, sourceId: "vow:s1")

        backup.backup(userId: userId)
        backup.backup(userId: userId) // identical snapshot — must be skipped

        wallet.grant(50) // changes the durable snapshot
        backup.backup(userId: userId)

        // The chain is FIFO, so if the identical snapshot had patched it
        // would land before the third write.
        let updates = await spy.waitForUpdates(count: 2)
        XCTAssertEqual(updates.count, 2, "an identical snapshot must not re-patch")
        let balances = try updates.map { try decodedPayload($0).wallet.balance }
        XCTAssertEqual(balances, [100, 150])
    }

    // MARK: - (g) highest cosmetic tier max-merges

    func test_highest_cosmetic_tier_max_merges() {
        _ = RankCosmetics.recordUnlockedTier(userId: userId, currentTier: .veteran, defaults: defaults)

        seed(cloudBackup(cosmetics: RewardsBackup.Cosmetics(highestTier: SkillTier.novice.rawValue)))
        XCTAssertEqual(
            RankCosmetics.persistedHighestTierRawValue(userId: userId, defaults: defaults),
            SkillTier.veteran.rawValue,
            "a lower cloud tier never regresses local"
        )

        seed(cloudBackup(cosmetics: RewardsBackup.Cosmetics(highestTier: SkillTier.master.rawValue)))
        XCTAssertEqual(
            RankCosmetics.persistedHighestTierRawValue(userId: userId, defaults: defaults),
            SkillTier.master.rawValue,
            "a higher cloud tier raises local"
        )
    }

    // MARK: - Store hook seams

    func test_wallet_and_shop_writes_fire_the_backup_seam() {
        let seam = BackupSpy()
        let wallet = CurrencyWalletStore(defaults: defaults, backup: seam)
        wallet.bind(userId: userId)

        wallet.grant(300)
        XCTAssertEqual(seam.userIds, [userId], "grant fires after it persists")
        XCTAssertTrue(wallet.grant(100, sourceId: "vow:s1"))
        XCTAssertTrue(wallet.spend(50))
        XCTAssertEqual(seam.userIds.count, 3)
        XCTAssertFalse(wallet.grant(100, sourceId: "vow:s1"), "duplicate grant is a no-op")
        XCTAssertEqual(seam.userIds.count, 3, "a no-op grant must not fire the seam")

        let inventory = ShopInventoryStore(defaults: defaults, backup: seam)
        inventory.bind(userId: userId)
        let item = ShopCatalog.item(id: "profileBorder.tapeWrap")!
        wallet.grant(item.price, sourceId: "vow:fund") // 4th
        XCTAssertEqual(inventory.purchase(item, wallet: wallet), .purchased) // spend (5th) + purchase (6th)
        inventory.setEquippedProfileBorder(.tapeWrap) // 7th
        XCTAssertEqual(seam.userIds.count, 7)
    }
}

// MARK: - Test doubles

/// Records every `update` so tests can assert the patch shape and that writes
/// land in call order. All other CRUD is inert.
private actor SpyDatabase: DatabaseServiceProtocol {
    struct Update {
        let fields: [String: Any]
        let collection: String
        let documentId: String
    }

    private(set) var updates: [Update] = []

    func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
        updates.append(Update(fields: fields, collection: collection, documentId: documentId))
    }

    /// Polls until `count` updates have drained through the backup's ordered
    /// write chain (the chain is fire-and-forget, so tests can't await it
    /// directly).
    func waitForUpdates(count: Int, timeout: TimeInterval = 5) async -> [Update] {
        let deadline = Date().addingTimeInterval(timeout)
        while updates.count < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return updates
    }

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {}

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        throw SpyDatabaseError.unsupported
    }

    func delete(collection: String, documentId: String) async throws {}

    func query<T: Codable>(collection: String, field: String, isEqualTo value: Any, orderBy: String?, descending: Bool, limit: Int?) async throws -> [T] {
        []
    }
}

private enum SpyDatabaseError: Error {
    case unsupported
}

/// Synchronous recorder for the stores' optional backup seam.
private final class BackupSpy: RewardsBackuping, @unchecked Sendable {
    private(set) var userIds: [String] = []

    func backup(userId: String) {
        userIds.append(userId)
    }
}
