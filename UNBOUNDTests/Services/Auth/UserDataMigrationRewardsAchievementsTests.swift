import XCTest
@testable import UNBOUND

// Covers the two per-user-UserDefaults progress domains of the sign-in
// migration: wallet/shop/cosmetics and titles/vows/badges. Both stores replay
// their domain's *CloudBackup restore merge with the LEGACY user's snapshot,
// so these tests pin the migration-visible contract: re-key onto the Supabase
// id, wallet never sums or refunds, purchases/titles/badges union (earliest
// badge date wins), legacy keys untouched, and the cloud mirror firing under
// the Supabase id.

// MARK: - Spies

private final class SpyRewardsBackup: RewardsBackuping, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    var userIds: [String] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func backup(userId: String) {
        lock.lock(); defer { lock.unlock() }
        recorded.append(userId)
    }
}

private final class SpyAchievementsBackup: AchievementsBackuping, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    var userIds: [String] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func backup(userId: String) {
        lock.lock(); defer { lock.unlock() }
        recorded.append(userId)
    }
}

// MARK: - Rewards (wallet + shop + cosmetics)

@MainActor
final class UserDataMigrationRewardsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var spy: SpyRewardsBackup!
    private var sut: ProductionUserDataMigrationRewardsStore!
    private let legacyUserId = "legacy-user"
    private let supabaseUserId = UUID().uuidString

    override func setUp() {
        super.setUp()
        suiteName = "UserDataMigrationRewardsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        spy = SpyRewardsBackup()
        // Isolated stores so the merge never touches the app's live singletons.
        sut = ProductionUserDataMigrationRewardsStore(
            helper: RewardsCloudBackup(database: UserDataMigrationFakeDatabase(), defaults: defaults),
            backup: spy,
            defaults: defaults,
            wallet: CurrencyWalletStore(defaults: defaults),
            inventory: ShopInventoryStore(defaults: defaults),
            skinService: SkinService(defaults: defaults)
        )
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func seedLegacyWallet(balance: Int, ledger: Set<String>) {
        CurrencyWalletStore.restorePersisted(balance: balance, userId: legacyUserId, defaults: defaults)
        CurrencyWalletStore.restorePersisted(grantLedger: ledger, userId: legacyUserId, defaults: defaults)
    }

    func test_legacy_only_rekeys_wallet_purchases_equips_and_cosmetics() async throws {
        seedLegacyWallet(balance: 500, ledger: ["vow:s1"])
        let border = try XCTUnwrap(ShopCatalog.item(id: "profileBorder.tapeWrap"))
        ShopInventoryStore.markPurchased(border, userId: legacyUserId, defaults: defaults)
        ShopInventoryStore.setEquippedProfileBorder(.tapeWrap, userId: legacyUserId, defaults: defaults)
        _ = RankCosmetics.recordUnlockedTier(userId: legacyUserId, currentTier: .veteran, defaults: defaults)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .rekeyed)
        // Empty target wallet adopts the legacy balance; the ledger unions.
        XCTAssertEqual(CurrencyWalletStore.persistedBalance(userId: supabaseUserId, defaults: defaults), 500)
        XCTAssertEqual(CurrencyWalletStore.persistedGrantLedger(userId: supabaseUserId, defaults: defaults), ["vow:s1"])
        XCTAssertTrue(ShopInventoryStore.purchasedItemIDs(userId: supabaseUserId, defaults: defaults).contains(border.id))
        XCTAssertEqual(
            ShopInventoryStore.equippedSlotSnapshot(userId: supabaseUserId, defaults: defaults).profileBorder,
            ShopProfileBorderID.tapeWrap.rawValue
        )
        XCTAssertEqual(
            RankCosmetics.persistedHighestTierRawValue(userId: supabaseUserId, defaults: defaults),
            SkillTier.veteran.rawValue
        )
        // Legacy keys stay in place as harmless orphans, matching rank.
        XCTAssertEqual(CurrencyWalletStore.persistedBalance(userId: legacyUserId, defaults: defaults), 500)
        XCTAssertTrue(ShopInventoryStore.purchasedItemIDs(userId: legacyUserId, defaults: defaults).contains(border.id))
        // Cloud mirror fired under the NEW id.
        XCTAssertEqual(spy.userIds, [supabaseUserId])
    }

    func test_both_sides_wallet_keeps_target_balance_and_never_sums() async throws {
        seedLegacyWallet(balance: 500, ledger: ["l1"])
        let border = try XCTUnwrap(ShopCatalog.item(id: "profileBorder.tapeWrap"))
        ShopInventoryStore.markPurchased(border, userId: legacyUserId, defaults: defaults)
        CurrencyWalletStore.restorePersisted(balance: 120, userId: supabaseUserId, defaults: defaults)
        CurrencyWalletStore.restorePersisted(grantLedger: ["t1"], userId: supabaseUserId, defaults: defaults)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .merged)
        // Non-empty target wallet stands: not 620 (sum), not 500 (overwrite).
        XCTAssertEqual(CurrencyWalletStore.persistedBalance(userId: supabaseUserId, defaults: defaults), 120)
        XCTAssertEqual(
            CurrencyWalletStore.persistedGrantLedger(userId: supabaseUserId, defaults: defaults),
            ["l1", "t1"]
        )
        XCTAssertTrue(ShopInventoryStore.purchasedItemIDs(userId: supabaseUserId, defaults: defaults).contains(border.id))
    }

    func test_spent_down_target_wallet_is_not_refunded() async {
        seedLegacyWallet(balance: 500, ledger: ["l1"])
        // Balance 0 with a non-empty ledger is a SPENT wallet, not a fresh one.
        CurrencyWalletStore.restorePersisted(balance: 0, userId: supabaseUserId, defaults: defaults)
        CurrencyWalletStore.restorePersisted(grantLedger: ["t1"], userId: supabaseUserId, defaults: defaults)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .merged)
        XCTAssertEqual(CurrencyWalletStore.persistedBalance(userId: supabaseUserId, defaults: defaults), 0)
        XCTAssertEqual(
            CurrencyWalletStore.persistedGrantLedger(userId: supabaseUserId, defaults: defaults),
            ["l1", "t1"]
        )
    }

    func test_target_only_is_noLegacy_with_zero_writes() async {
        CurrencyWalletStore.restorePersisted(balance: 120, userId: supabaseUserId, defaults: defaults)
        CurrencyWalletStore.restorePersisted(grantLedger: ["t1"], userId: supabaseUserId, defaults: defaults)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .noLegacy)
        XCTAssertEqual(CurrencyWalletStore.persistedBalance(userId: supabaseUserId, defaults: defaults), 120)
        XCTAssertEqual(CurrencyWalletStore.persistedGrantLedger(userId: supabaseUserId, defaults: defaults), ["t1"])
        XCTAssertTrue(spy.userIds.isEmpty)
    }
}

// MARK: - Achievements (titles + vows + badges)

@MainActor
final class UserDataMigrationAchievementsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var spy: SpyAchievementsBackup!
    private var vowsStore: WeeklyVowsStore!
    private var sut: ProductionUserDataMigrationAchievementsStore!
    private let legacyUserId = "legacy-user"
    private let supabaseUserId = UUID().uuidString
    // Whole-second dates: badge/vow ids and the wire format floor to seconds.
    private let early = Date(timeIntervalSince1970: 1_700_000_000)
    private let late = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "UserDataMigrationAchievementsStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        spy = SpyAchievementsBackup()
        vowsStore = WeeklyVowsStore(defaults: defaults)
        sut = ProductionUserDataMigrationAchievementsStore(
            helper: AchievementsCloudBackup(database: UserDataMigrationFakeDatabase(), defaults: defaults),
            backup: spy,
            defaults: defaults,
            vowsStore: vowsStore
        )
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func title(_ rank: RankTier) -> TitleID {
        TitleID(path: .rank(rank), tier: .gold)
    }

    private func keptVow(_ vowId: String, at date: Date) -> KeptVow {
        KeptVow(vowId: vowId, name: "Vow \(vowId)", lane: .fuel, completedAt: date)
    }

    func test_legacy_only_rekeys_titles_vows_and_badges() async {
        var legacy = WeeklyVowsState.empty
        legacy.unlockedTitles = [title(.forged)]
        legacy.equippedTitle = title(.forged)
        legacy.keptVows = [keptVow("v1", at: early)]
        legacy.completionsByLane = [.fuel: 3]
        vowsStore.save(legacy, userId: legacyUserId)
        BadgeUnlockStore.save(["b1": early], userId: legacyUserId, defaults: defaults)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .rekeyed)
        let migrated = vowsStore.load(userId: supabaseUserId)
        XCTAssertEqual(migrated.unlockedTitles, [title(.forged)])
        XCTAssertEqual(migrated.equippedTitle, title(.forged))
        XCTAssertEqual(migrated.keptVows.map(\.vowId), ["v1"])
        XCTAssertEqual(migrated.completionsByLane[.fuel], 3)
        XCTAssertEqual(BadgeUnlockStore.load(userId: supabaseUserId, defaults: defaults), ["b1": early])
        // Legacy keys stay in place as harmless orphans, matching rank.
        XCTAssertEqual(vowsStore.load(userId: legacyUserId).unlockedTitles, [title(.forged)])
        XCTAssertEqual(BadgeUnlockStore.load(userId: legacyUserId, defaults: defaults), ["b1": early])
        // Cloud mirror fired under the NEW id.
        XCTAssertEqual(spy.userIds, [supabaseUserId])
    }

    func test_both_sides_merge_unions_titles_takes_earliest_badge_and_max_lane_count() async {
        var legacy = WeeklyVowsState.empty
        legacy.unlockedTitles = [title(.forged)]
        legacy.keptVows = [keptVow("v1", at: early)]
        legacy.completionsByLane = [.fuel: 5]
        vowsStore.save(legacy, userId: legacyUserId)
        BadgeUnlockStore.save(["b1": early], userId: legacyUserId, defaults: defaults)

        var target = WeeklyVowsState.empty
        target.unlockedTitles = [title(.veteran)]
        target.equippedTitle = title(.veteran)
        target.keptVows = [keptVow("v2", at: late)]
        target.completionsByLane = [.fuel: 2, .engine: 1]
        vowsStore.save(target, userId: supabaseUserId)
        BadgeUnlockStore.save(["b1": late, "b2": late], userId: supabaseUserId, defaults: defaults)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .merged)
        let merged = vowsStore.load(userId: supabaseUserId)
        // Union with the target's (local) order first; local equip stands.
        XCTAssertEqual(merged.unlockedTitles, [title(.veteran), title(.forged)])
        XCTAssertEqual(merged.equippedTitle, title(.veteran))
        XCTAssertEqual(Set(merged.keptVows.map(\.vowId)), ["v1", "v2"])
        // Per-lane MAX — a restore can never double-count completions.
        XCTAssertEqual(merged.completionsByLane[.fuel], 5)
        XCTAssertEqual(merged.completionsByLane[.engine], 1)
        // Earliest unlock date is the true unlock moment.
        let badges = BadgeUnlockStore.load(userId: supabaseUserId, defaults: defaults)
        XCTAssertEqual(badges["b1"], early)
        XCTAssertEqual(badges["b2"], late)
        XCTAssertEqual(spy.userIds, [supabaseUserId])
    }

    func test_empty_legacy_is_noLegacy_with_zero_writes() async {
        var target = WeeklyVowsState.empty
        target.unlockedTitles = [title(.veteran)]
        vowsStore.save(target, userId: supabaseUserId)

        let outcome = await sut.migrate(legacyUserId: legacyUserId, supabaseUserId: supabaseUserId)

        XCTAssertEqual(outcome, .noLegacy)
        XCTAssertEqual(vowsStore.load(userId: supabaseUserId).unlockedTitles, [title(.veteran)])
        XCTAssertTrue(spy.userIds.isEmpty)
    }
}
