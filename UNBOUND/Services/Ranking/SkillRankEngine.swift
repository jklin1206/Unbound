import Foundation

// MARK: - SkillRankEngine (prototype)
//
// Pure: ranks a skill through 5 DISCRETE stars from its own movement's best. A star
// fills when best ≥ that threshold — no curve, no bar. Past 5 stars it just carries
// the PB. Own-movement only (council invariant).

enum SkillRankEngine {

    static func rank(
        _ standard: SkillRankStandard,
        logs: [WorkoutLog],
        bodyweightKg: Double
    ) -> SkillRankResult {
        let best = bestScore(standard.metric, logs: logs, bodyweightKg: bodyweightKg)
        // Stars = how many ascending thresholds the best has cleared (capped at 5).
        let stars = min(5, standard.thresholds.filter { best >= $0 }.count)
        let nextThreshold = stars < standard.thresholds.count ? standard.thresholds[stars] : nil
        return SkillRankResult(stars: stars, best: best, nextThreshold: nextThreshold)
    }

    /// Weighted points toward the overall athlete rank = stars × difficulty weight
    /// (a star on a muscle-up counts more than a star on a pull-up).
    static func weightedPoints(_ result: SkillRankResult, weight: Int) -> Int {
        result.stars * weight
    }

    // MARK: Best score on a skill's own movement

    static func bestScore(_ metric: SkillMetric, logs: [WorkoutLog], bodyweightKg: Double) -> Double {
        switch metric {
        case .reps(let exercise):
            return Double(matchingSets(exercise, logs).map(\.reps).max() ?? 0)
        case .seconds(let exercise):
            return Double(matchingSets(exercise, logs).map { $0.durationSeconds ?? $0.reps }.max() ?? 0)
        case .bodyweightRatio(let exercise):
            guard bodyweightKg > 0 else { return 0 }
            return (matchingSets(exercise, logs).compactMap(\.weightKg).max() ?? 0) / bodyweightKg
        }
    }

    private static func matchingSets(_ exercise: String, _ logs: [WorkoutLog]) -> [SetLog] {
        logs.flatMap { $0.exerciseEntries }
            .filter { MovementProofMatcher.namesMatch(logged: $0.exerciseName, required: exercise) }
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
    }
}
