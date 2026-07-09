import Foundation

// Production stores for the two per-user-UserDefaults progress domains the
// sign-in migration carries: wallet/shop/cosmetic prefs and titles/vows/
// badges. Neither re-implements merge semantics — both delegate to their
// domain's *CloudBackup service (the single source of truth for that merge),
// pointing its restore path at the legacy user's snapshot instead of a cloud
// payload. Legacy keys stay in place as harmless orphans, matching rank.

// MARK: - Rewards (wallet + shop + cosmetic prefs)

/// Carries the Arcs wallet, purchased shop items, equipped slots, rank
/// cosmetics, showcase, and skin preference onto the Supabase id by replaying
/// `RewardsCloudBackup.seedLocalStores` with the LEGACY user's raw snapshot:
/// wallet adopt-when-target-empty + grant-ledger union, purchases set-union,
/// ownership-guarded equips, adopt-when-unset preferences, highest-tier max.
struct ProductionUserDataMigrationRewardsStore: UserDataMigrationRewardsStoring, @unchecked Sendable {
    private let helper: RewardsCloudBackup
    private let backup: any RewardsBackuping
    private let defaults: UserDefaults
    private let wallet: CurrencyWalletStore?
    private let inventory: ShopInventoryStore?
    private let skinService: SkinService?

    /// `wallet` / `inventory` / `skinService` default to the live singletons
    /// (resolved lazily on the main actor) so a merged wallet rebinds the
    /// already-visible `@Published` state; tests inject isolated instances.
    init(
        helper: RewardsCloudBackup = .shared,
        backup: any RewardsBackuping = RewardsCloudBackup.shared,
        defaults: UserDefaults = .standard,
        wallet: CurrencyWalletStore? = nil,
        inventory: ShopInventoryStore? = nil,
        skinService: SkinService? = nil
    ) {
        self.helper = helper
        self.backup = backup
        self.defaults = defaults
        self.wallet = wallet
        self.inventory = inventory
        self.skinService = skinService
    }

    func migrate(legacyUserId: String, supabaseUserId: String) async -> RewardsMigrationOutcome {
        // One main-actor hop: the seed's equip setters are @MainActor, and
        // doing the read-merge-write in one hop keeps it atomic with respect
        // to a concurrent purchase/equip on the same keys.
        await MainActor.run { () -> RewardsMigrationOutcome in
            // Raw persisted reads only: the snapshot bypasses the DEBUG
            // unlimited-credits short-circuit, so a dev-inflated balance can
            // never leak into the merge.
            let legacy = helper.snapshot(userId: legacyUserId)
            guard legacy.hasMigratableData else { return .noLegacy }

            let before = helper.snapshot(userId: supabaseUserId)
            helper.seedLocalStores(
                from: legacy,
                userId: supabaseUserId,
                wallet: wallet ?? .shared,
                inventory: inventory ?? .shared,
                skinService: skinService ?? .shared,
                defaults: defaults
            )

            // Mirror the merged state to the users doc (outboxed, retried) so
            // the cloud backup is immediately fresh under the new id.
            backup.backup(userId: supabaseUserId)

            let after = helper.snapshot(userId: supabaseUserId)
            if after == before { return .unchanged }
            return before.hasMigratableData ? .merged : .rekeyed
        }
    }
}

extension RewardsBackup {
    /// True when any per-user field carries data. `cosmetics.currentSkin` is
    /// deliberately excluded: the skin selection is a device-GLOBAL key,
    /// identical on both sides of the same sign-in, so it cannot distinguish
    /// legacy progress from none.
    var hasMigratableData: Bool {
        wallet.balance > 0
            || !wallet.grantLedger.isEmpty
            || !shop.purchased.isEmpty
            || shop.equippedHomeBackground != nil
            || shop.equippedHomeBackdrop != nil
            || shop.equippedProfileBorder != nil
            || shop.equippedProfileBackground != nil
            || shop.equippedProfileBackdrop != nil
            || cosmetics.highestTier != nil
            || cosmetics.frameTier != nil
            || cosmetics.backgroundTier != nil
            || cosmetics.showcase != nil
    }
}

// MARK: - Achievements (titles + vows + badges)

/// Carries unlocked titles, the kept-vows history, per-lane counters, vow
/// ledgers, and the badge unlock map onto the Supabase id by replaying
/// `AchievementsCloudBackup.seedLocalStores` with the LEGACY user's durable
/// snapshot: title union, keptVows union-by-id, per-lane max, ledger unions,
/// badges union with the earliest unlock date winning.
struct ProductionUserDataMigrationAchievementsStore: UserDataMigrationAchievementsStoring, @unchecked Sendable {
    private let helper: AchievementsCloudBackup
    private let backup: any AchievementsBackuping
    private let defaults: UserDefaults
    private let vowsStore: WeeklyVowsStore?

    /// `vowsStore` defaults to the live `.shared` store (resolved lazily on
    /// the main actor) so the merged state lands where the app reads AND
    /// re-mirrors through the store's own backup seam; tests inject an
    /// isolated store.
    init(
        helper: AchievementsCloudBackup = .shared,
        backup: any AchievementsBackuping = AchievementsCloudBackup.shared,
        defaults: UserDefaults = .standard,
        vowsStore: WeeklyVowsStore? = nil
    ) {
        self.helper = helper
        self.backup = backup
        self.defaults = defaults
        self.vowsStore = vowsStore
    }

    func migrate(legacyUserId: String, supabaseUserId: String) async -> AchievementsMigrationOutcome {
        // One main-actor hop keeps the read-merge-write atomic with respect
        // to a concurrent unlock landing on the same keys.
        await MainActor.run { () -> AchievementsMigrationOutcome in
            // Seam-free reader over the same defaults the production store
            // writes: reading must not fire the live store's cloud mirror.
            let reader = WeeklyVowsStore(defaults: defaults)
            let legacy = AchievementsBackup(
                state: reader.load(userId: legacyUserId),
                badges: BadgeUnlockStore.load(userId: legacyUserId, defaults: defaults)
            )
            guard legacy.hasMigratableData else { return .noLegacy }

            let before = AchievementsBackup(
                state: reader.load(userId: supabaseUserId),
                badges: BadgeUnlockStore.load(userId: supabaseUserId, defaults: defaults)
            )
            helper.seedLocalStores(
                from: legacy,
                userId: supabaseUserId,
                vowsStore: vowsStore ?? .shared,
                badgeDefaults: defaults
            )

            // Explicit mirror (the vows store's own seam only fires when the
            // vows state changed; a badges-only merge still needs the patch).
            backup.backup(userId: supabaseUserId)

            let after = AchievementsBackup(
                state: reader.load(userId: supabaseUserId),
                badges: BadgeUnlockStore.load(userId: supabaseUserId, defaults: defaults)
            )
            if after == before { return .unchanged }
            return before.hasMigratableData ? .merged : .rekeyed
        }
    }
}

extension AchievementsBackup {
    /// True when any durable field carries data (the weekly-ephemeral fields
    /// never migrate — they regenerate on the Monday roll).
    var hasMigratableData: Bool {
        !unlockedTitles.isEmpty
            || equippedTitle != nil
            || !keptVows.isEmpty
            || completionsByLane.values.contains { $0 > 0 }
            || !weeklyVowCompletionLedger.isEmpty
            || !weeklyVowPenaltyLedger.isEmpty
            || !badges.isEmpty
    }
}
