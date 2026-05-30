import Foundation

// MARK: - StarRatingEngine (prototype)
//
// Pure: rates a node against its StarStandard using the user's logs. Reads ONLY
// the node's own movement (the council's invariant — no cross-exercise ranking).
// Mirrors TierCriterionEvaluator's matching so results are consistent.

enum StarRatingEngine {

    /// Rate a single node's standard against the log pool.
    static func rate(
        _ standard: StarStandard,
        logs: [WorkoutLog],
        bodyweightKg: Double
    ) -> StarRating {
        let best = bestScore(standard.metric, logs: logs, bodyweightKg: bodyweightKg)
        let stars = standard.thresholds.filter { best >= $0 }.count

        // Progress toward the next star: interpolate between the current and next threshold.
        let lower: Double
        let upper: Double?
        switch stars {
        case 0: lower = 0;                upper = standard.oneStar
        case 1: lower = standard.oneStar; upper = standard.twoStar
        case 2: lower = standard.twoStar; upper = standard.threeStar
        default:
            return StarRating(stars: 3, bestScore: best, progressToNext: 1, nextThreshold: nil, metric: standard.metric)
        }
        let progress: Double = {
            guard let upper, upper > lower else { return 0 }
            return min(1, max(0, (best - lower) / (upper - lower)))
        }()
        return StarRating(stars: stars, bestScore: best, progressToNext: progress, nextThreshold: upper, metric: standard.metric)
    }

    // MARK: Best score on a node's own movement

    static func bestScore(_ metric: StarMetric, logs: [WorkoutLog], bodyweightKg: Double) -> Double {
        switch metric {
        case .reps(let exercise):
            return Double(matchingSets(exercise, logs).map(\.reps).max() ?? 0)
        case .seconds(let exercise):
            return Double(matchingSets(exercise, logs).map { $0.durationSeconds ?? $0.reps }.max() ?? 0)
        case .bodyweightRatio(let exercise):
            guard bodyweightKg > 0 else { return 0 }
            let bestLoad = matchingSets(exercise, logs).compactMap(\.weightKg).max() ?? 0
            return bestLoad / bodyweightKg
        }
    }

    /// Non-warmup sets whose exercise matches `exercise` (movement-aware).
    private static func matchingSets(_ exercise: String, _ logs: [WorkoutLog]) -> [SetLog] {
        logs.flatMap { $0.exerciseEntries }
            .filter { MovementProofMatcher.namesMatch(logged: $0.exerciseName, required: exercise) }
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
    }
}
