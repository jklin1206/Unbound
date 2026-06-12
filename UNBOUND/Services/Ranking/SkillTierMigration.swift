import Foundation

/// One-time migration that walks the user's full log history and seeds
/// UserSkillTierState. Idempotent — guarded by UserDefaults flag.
///
/// Called after `auth.currentUserId` resolves in
/// `UnboundApp.swift` (RootView .task block), passing
///   userId  = services.auth.currentUserId ?? "anonymous"
///   history = all ExerciseLogEntry items flattened from
///             services.workoutLog.fetchLogs(userId:programId:nil)
///   bodyweightKg = profile.weightKg ?? 70
@MainActor
enum SkillTierMigration {

    private static let migratedFlagKey = "unbound.skillTier.migratedV1"
    private static let tuckBackLeverBackfillFlagKey = "unbound.skillTier.migratedV2.tuckBackLever"

    /// Returns true if migration ran this call.
    @discardableResult
    static func migrateIfNeeded(
        userId: String,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> Bool {
        migrateIfNeeded(
            userId: userId,
            history: history,
            bodyweightKg: bodyweightKg,
            rankService: RankService.shared,
            store: .shared,
            defaults: .standard
        )
    }

    /// Returns true if migration ran this call.
    @discardableResult
    static func migrateIfNeeded(
        userId: String,
        history: [ExerciseLogEntry],
        bodyweightKg: Double,
        rankService: RankServiceProtocol,
        store: UserSkillTierStore,
        defaults: UserDefaults
    ) -> Bool {
        let didBackfill = backfillTuckBackLeverIfNeeded(
            userId: userId,
            store: store,
            defaults: defaults
        )

        let key = "\(migratedFlagKey).\(userId)"
        guard !defaults.bool(forKey: key) else { return didBackfill }

        var state = UserSkillTierState.empty
        for skill in SkillGraph.shared.nodes {
            let tier = rankService.computeTier(
                skill: skill,
                history: history,
                bodyweightKg: bodyweightKg
            )
            if tier != .initiate {
                state.perSkill[skill.id] = tier
            }
            if tier == .unbound {
                state.ascendantSkills.append(skill.id)
            }
        }
        applyTuckBackLeverBackfill(to: &state, updateRankUpsEarned: false)

        // rankUpsEarned: sum of tier ordinals across all non-initiate skills.
        // Each skill at tier N contributed N crossings to get there, matching
        // the semantics of RankService.evaluate which adds
        // (newTier.rawValue - priorTier.rawValue) per advance.
        state.rankUpsEarned = state.perSkill.values
            .filter { $0 != .initiate }
            .map { $0.rawValue }
            .reduce(0, +)

        store.save(state, userId: userId)
        defaults.set(true, forKey: key)
        return true
    }

    private static func backfillTuckBackLeverIfNeeded(
        userId: String,
        store: UserSkillTierStore,
        defaults: UserDefaults
    ) -> Bool {
        let key = "\(tuckBackLeverBackfillFlagKey).\(userId)"
        guard !defaults.bool(forKey: key) else { return false }

        var state = store.load(userId: userId)
        let changed = applyTuckBackLeverBackfill(to: &state, updateRankUpsEarned: true)
        if changed {
            store.save(state, userId: userId)
        }
        defaults.set(true, forKey: key)
        return changed
    }

    @discardableResult
    private static func applyTuckBackLeverBackfill(
        to state: inout UserSkillTierState,
        updateRankUpsEarned: Bool
    ) -> Bool {
        let downstreamTier = [
            state.perSkill["cl.straddle-back-lever"],
            state.perSkill["cl.full-back-lever"]
        ]
        .compactMap { $0 }
        .max()

        guard let downstreamTier, downstreamTier >= .forged else { return false }

        let targetTier: SkillTier = downstreamTier >= .veteran ? .veteran : .forged
        let currentTier = state.tier(for: "cl.tuck-back-lever")
        guard currentTier < targetTier else { return false }

        state.perSkill["cl.tuck-back-lever"] = targetTier
        if updateRankUpsEarned {
            state.rankUpsEarned += targetTier.rawValue - currentTier.rawValue
        }
        return true
    }
}
