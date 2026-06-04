import Foundation

@MainActor
protocol RankServiceProtocol: AnyObject {
    // MARK: - SkillTier API (Phase 4+)

    /// Pure: returns the highest tier whose criterion is satisfied by the
    /// user's log history for this skill. Defaults to .initiate if nothing matches.
    func computeTier(
        skill: SkillNode,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> SkillTier

    // MARK: - Ascension Tier API

    /// Evaluate tier crossings introduced by the new log.
    /// Returns list of SkillTierAdvance per skill that crossed.
    func evaluateTierCrossings(log: WorkoutLog, userId: String) async -> [SkillTierAdvance]

    /// Load the full UserSkillTierState for a user. Used by views that need
    /// per-skill tier lookups without going through async evaluateTierCrossings.
    func state(userId: String) -> UserSkillTierState

    /// Aggregate skill tier across all per-skill + per-lift states.
    /// Returns the highest tier reached.
    func aggregateTier(userId: String) async -> SkillTier

    // MARK: - Legacy lift-rank API

    /// Compute a lift's RankTier from a workout log entry. Returns nil when
    /// the exercise isn't a tracked lift or the log lacks usable data.
    func computeLiftRank(
        entry: ExerciseLogEntry,
        bodyweightKg: Double,
        sex: BiologicalSex?
    ) -> RankTier?

    /// Evaluate every entry in a log for session-time lift-rank advances.
    /// The modern path posts `.rankAdvanced` from an in-memory session cache;
    /// persisted movement progress is owned by `MovementProgressService`.
    /// `sex` selects the male/female strength-standard column (male default
    /// when nil).
    func evaluate(log: WorkoutLog, bodyweightKg: Double, sex: BiologicalSex?) async

    /// Compute the user's current build-weighted rank. This is different from
    /// `aggregateTier(userId:)`, which returns the highest rank ever unlocked.
    /// The weighted rank reads the user's AttributeProfile, derives
    /// BuildIdentity, then averages currentRank across the relevant
    /// AttributeKey.emphasisLifts.
    func aggregateRank(userId: String) async -> RankTier

}
