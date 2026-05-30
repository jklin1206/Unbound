import Foundation

// MARK: - SkillRankEngine (prototype)
//
// Pure: ranks a skill on the 9-tier RankTier from ONE standard (best ÷ standard
// → shared band curve), reading only the skill's own movement. Same shape as a
// lift's RankTier from StrengthStandards — one language across the app.

enum SkillRankEngine {

    /// Map best÷standard into a continuous tier POSITION (0 = Initiate … 8 = peak).
    /// ratio 1.0 (you hit the standard) → 3.0 = Forged. Below the standard spans
    /// Initiate→Forged; above it spans Forged→peak (elite ≈ 3× the standard).
    static func tierPosition(ratio: Double) -> Double {
        guard ratio > 0 else { return 0 }
        if ratio <= 1.0 { return min(3.0, 3.0 * ratio) }
        return min(8.0, 3.0 + (ratio - 1.0) / 2.0 * 5.0)
    }

    static func rank(
        _ standard: SkillRankStandard,
        logs: [WorkoutLog],
        bodyweightKg: Double
    ) -> SkillRankResult {
        let best = bestScore(standard.metric, logs: logs, bodyweightKg: bodyweightKg)
        let pos = tierPosition(ratio: standard.standard > 0 ? best / standard.standard : 0)

        let floorIdx = min(8, Int(pos))
        let tier = RankTier(rawValue: floorIdx) ?? .initiate
        let nextTier = RankTier(rawValue: floorIdx + 1)
        let progress = nextTier == nil ? 1.0 : pos - Double(floorIdx)
        return SkillRankResult(tier: tier, best: best, progressToNextTier: progress, nextTier: nextTier)
    }

    /// Weighted points toward the overall athlete rank = tier ordinal × weight.
    static func weightedPoints(_ result: SkillRankResult, weight: Int) -> Int {
        result.tier.rawValue * weight
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
