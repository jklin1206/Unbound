import Foundation

/// Pure: evaluates a single TierCriterion against the user's log history.
/// No state, no I/O. The single source of truth for criterion semantics.
///
/// Exercise-name comparisons are case-insensitive and trim whitespace.
/// Warmup sets are excluded from all calculations.
///
/// .seconds reads `SetLog.durationSeconds` (Foundation 2), falling back to
/// `reps` for legacy logs that encoded hold seconds in the reps column.
enum TierCriterionEvaluator {

    static func satisfied(
        criterion: TierCriterion,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> Bool {
        switch criterion {
        case .reps(let target, let exerciseName):
            return bestReps(for: exerciseName, in: history) >= target

        case .seconds(let target):
            // Global: best hold across ALL logged exercises. Prefer
            // .exerciseSeconds for hold skills (history is NOT pre-filtered).
            return bestSeconds(in: history) >= target

        case .exerciseSeconds(let target, let exerciseName):
            return bestSeconds(for: exerciseName, in: history) >= target

        case .weightKg(let target):
            return bestWeight(in: history) >= target

        case .exerciseWeightKg(let target, let exerciseName):
            return bestWeight(for: exerciseName, in: history) >= target

        case .bodyweightRatio(let target):
            guard bodyweightKg > 0 else { return false }
            return (bestWeight(in: history) / bodyweightKg) >= target

        case .exerciseBodyweightRatio(let target, let exerciseName):
            guard bodyweightKg > 0 else { return false }
            return (bestWeight(for: exerciseName, in: history) / bodyweightKg) >= target

        case .variant(let name):
            return history.contains { entry in
                MovementProofMatcher.entry(entry, satisfies: name)
            }

        case .compound(let subs):
            return subs.allSatisfy { satisfied(criterion: $0, history: history, bodyweightKg: bodyweightKg) }
        }
    }

    // MARK: helpers

    private static func matchingEntries(
        exerciseName: String,
        in history: [ExerciseLogEntry]
    ) -> [ExerciseLogEntry] {
        return history.filter {
            MovementProofMatcher.entry($0, satisfies: exerciseName)
        }
    }

    private static func bestReps(for exerciseName: String, in history: [ExerciseLogEntry]) -> Int {
        matchingEntries(exerciseName: exerciseName, in: history)
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .map { $0.reps }
            .max() ?? 0
    }

    /// Best hold duration across ALL entries (global — any exercise). Reads
    /// `durationSeconds`, falling back to `reps` for legacy reps-column holds.
    private static func bestSeconds(in history: [ExerciseLogEntry]) -> Int {
        history
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .map { $0.durationSeconds ?? $0.reps }
            .max() ?? 0
    }

    /// Best hold duration for a single exercise. Exercise-scoped counterpart of
    /// `bestSeconds(in:)`. Reads `durationSeconds`, legacy reps-column fallback.
    private static func bestSeconds(for exerciseName: String, in history: [ExerciseLogEntry]) -> Int {
        matchingEntries(exerciseName: exerciseName, in: history)
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .map { $0.durationSeconds ?? $0.reps }
            .max() ?? 0
    }

    private static func bestWeight(for exerciseName: String, in history: [ExerciseLogEntry]) -> Double {
        matchingEntries(exerciseName: exerciseName, in: history)
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .compactMap { $0.weightKg }
            .max() ?? 0
    }

    /// Returns the heaviest weight across ALL entries in `history` regardless
    /// of exercise name. Callers passing multi-exercise history must pre-filter
    /// to the relevant exercise before calling, or `.weightKg` and
    /// `.bodyweightRatio` criteria can be satisfied by an unrelated lift.
    private static func bestWeight(in history: [ExerciseLogEntry]) -> Double {
        history
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .compactMap { $0.weightKg }
            .max() ?? 0
    }
}
