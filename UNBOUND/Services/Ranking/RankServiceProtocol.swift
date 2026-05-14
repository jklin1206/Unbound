import Foundation

@MainActor
protocol RankServiceProtocol: AnyObject {
    /// Compute a lift's sub-rank from a workout log entry. Returns nil when
    /// the exercise isn't a tracked lift or the log lacks usable data.
    func computeLiftRank(
        entry: ExerciseLogEntry,
        bodyweightKg: Double
    ) -> SubRank?

    /// Evaluate every entry in a log against persisted LiftRank state.
    /// Posts `.rankAdvanced` + persists per-lift updates. Called from
    /// ProgressionEngine after normal progression ingest.
    func evaluate(log: WorkoutLog, bodyweightKg: Double) async

    /// Aggregate sub-rank across the user's BuildIdentity primary axis (or
    /// top-3 axes for balanced/hybridAthlete). Reads the user's
    /// AttributeProfile via ServiceContainer.shared.attribute, derives
    /// BuildIdentity, then averages currentRank.ordinal across the relevant
    /// AttributeKey.emphasisLifts. Replaces archetypeRank in Phase 2c.
    func aggregateRank(userId: String) async -> SubRank

    /// All persisted lift ranks for the user, newest first.
    func fetchAll(userId: String) async -> [LiftRank]

    /// Persist a manually-mutated LiftRank (e.g. after decay).
    func save(_ rank: LiftRank) async
}
