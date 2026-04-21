import Foundation

// MARK: - MuscleGroupTierCalculator
//
// Deterministic compute of MuscleGroupTierState from scan data + recent
// workout logs. Parallel pattern to StaminaCalculator.
//
// Inputs:
//   - MuscleGroupAssessment (from BodyAnalysis.muscleAssessments)
//   - Recent workout logs (for the boost signal)
//
// Output:
//   - MuscleGroupTierState per muscle group
//
// Signal design:
//   scanBaseline (0–100) ← assessment.currentScore
//   logBoost     (−5…+15) ← recent lift PRs / working-weight multipliers
//                           on exercises tagged with this muscle group
//   score        = clamp(scanBaseline + logBoost, 0, 100)
//   tier         = MuscleGroupTier.from(score:)
//
// Log boost is intentionally capped so scan remains the dominant signal.
// If scan says C and you just hit a PR, you move to C+ or B — not jump
// to S. Earned rank matches visible physical change.

struct MuscleGroupTierCalculator {

    /// Minimal log shape the calculator needs. The real WorkoutLog model
    /// is richer — an adapter can map it into this struct at call time.
    struct LogSignal {
        let exerciseKey: String        // lowercase trimmed
        let muscleGroups: [MuscleGroup]
        /// 0.0–1.0 representing recent performance quality for this
        /// exercise. e.g. (currentWorkingWeight / bodyweight) clamped for
        /// compounds, rep-target attainment for bodyweight, etc.
        let performanceScalar: Double
        let date: Date
    }

    /// Compute all tier states for a user from an assessment list + logs.
    static func compute(
        userId: String,
        assessments: [MuscleGroupAssessment],
        logs: [LogSignal] = [],
        referenceDate: Date = .now
    ) -> [MuscleGroupTierState] {
        assessments.map { assessment in
            let scan = assessment.currentScore
            let boost = logBoost(
                for: assessment.muscleGroup,
                logs: logs,
                referenceDate: referenceDate
            )
            let score = max(0, min(100, scan + boost))
            let tier = MuscleGroupTier.from(score: score)
            return MuscleGroupTierState(
                userId: userId,
                muscleGroup: assessment.muscleGroup,
                tier: tier,
                score: score,
                scanBaseline: scan,
                logBoost: boost,
                updatedAt: referenceDate
            )
        }
    }

    /// Compute the tier for a single assessment without logs.
    /// Convenience for UI previews and lightweight surfaces.
    static func tierOnly(for assessment: MuscleGroupAssessment) -> MuscleGroupTier {
        MuscleGroupTier.from(score: assessment.currentScore)
    }

    // MARK: Log boost

    /// Recency-weighted performance boost for a muscle group.
    /// Range: −5 to +15. Logs older than `windowDays` are ignored.
    private static let windowDays: Int = 28
    private static let maxPositiveBoost: Int = 15
    private static let maxNegativeBoost: Int = -5

    private static func logBoost(
        for group: MuscleGroup,
        logs: [LogSignal],
        referenceDate: Date
    ) -> Int {
        guard !logs.isEmpty else { return 0 }

        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -windowDays,
            to: referenceDate
        ) ?? referenceDate

        let windowed = logs.filter {
            $0.muscleGroups.contains(group) && $0.date >= cutoff
        }
        guard !windowed.isEmpty else { return maxNegativeBoost }

        // Recency-weighted average of performance scalars (0–1).
        let halfLife: Double = 10 // days
        let weighted = windowed.reduce((0.0, 0.0)) { acc, log in
            let age = referenceDate.timeIntervalSince(log.date) / 86_400
            let w = pow(0.5, age / halfLife)
            return (acc.0 + log.performanceScalar * w, acc.1 + w)
        }
        let avg = weighted.1 > 0 ? weighted.0 / weighted.1 : 0

        // Map avg performance onto boost range. avg 0 → 0 boost.
        // avg 0.5 → +5. avg 1.0+ → +15.
        let raw = Int((avg * 30).rounded()) - 0
        return max(maxNegativeBoost, min(maxPositiveBoost, raw))
    }
}
