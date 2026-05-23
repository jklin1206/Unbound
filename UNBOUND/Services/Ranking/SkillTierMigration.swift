import Foundation

/// One-time migration that walks the user's full log history and seeds
/// UserSkillTierState. Idempotent — guarded by UserDefaults flag.
///
/// TODO: Wire into app startup once a cheap full-log fetch is available.
/// Current recommended call site: after `auth.currentUserId` resolves in
/// `AniBodyApp.swift` (RootView .task block), passing
///   userId  = services.auth.currentUserId ?? "anonymous"
///   history = all ExerciseLogEntry items flattened from
///             services.workoutLog.fetchLogs(userId:programId:nil)
///   bodyweightKg = profile.weightKg ?? 70
/// Until wired, sessions logged post-install hit RankService.evaluate directly
/// and tier state accumulates correctly going forward.
@MainActor
enum SkillTierMigration {

    private static let migratedFlagKey = "unbound.skillTier.migratedV1"

    /// Returns true if migration ran this call.
    @discardableResult
    static func migrateIfNeeded(
        userId: String,
        history: [ExerciseLogEntry],
        bodyweightKg: Double,
        rankService: RankServiceProtocol = RankService.shared,
        store: UserSkillTierStore = .shared,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let key = "\(migratedFlagKey).\(userId)"
        guard !defaults.bool(forKey: key) else { return false }

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
            if tier == .ascendant {
                state.ascendantSkills.append(skill.id)
            }
        }
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
}
