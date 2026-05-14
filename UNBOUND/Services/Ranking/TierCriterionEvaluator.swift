import Foundation

/// Pure: evaluates a single TierCriterion against the user's log history.
/// No state, no I/O. The single source of truth for criterion semantics.
///
/// Exercise-name comparisons are case-insensitive and trim whitespace.
/// Warmup sets are excluded from all calculations.
///
/// NOTE on .seconds: this codebase tracks holds by named-by-duration
/// exercises (e.g. "plank-30", "plank-60"), not by a seconds field on
/// SetLog. The .seconds branch always returns false. Hold-based tier
/// criteria should use .variant("plank-30") instead.
enum TierCriterionEvaluator {

    static func satisfied(
        criterion: TierCriterion,
        history: [ExerciseLogEntry],
        bodyweightKg: Double
    ) -> Bool {
        switch criterion {
        case .reps(let target, let exerciseName):
            return bestReps(for: exerciseName, in: history) >= target

        case .seconds:
            // No seconds tracking on SetLog — see file header comment.
            return false

        case .weightKg(let target):
            return bestWeight(in: history) >= target

        case .bodyweightRatio(let target):
            guard bodyweightKg > 0 else { return false }
            return (bestWeight(in: history) / bodyweightKg) >= target

        case .variant(let name):
            let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
            return history.contains { entry in
                entry.exerciseName.lowercased().trimmingCharacters(in: .whitespaces) == normalized
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
        let normalized = exerciseName.lowercased().trimmingCharacters(in: .whitespaces)
        return history.filter {
            $0.exerciseName.lowercased().trimmingCharacters(in: .whitespaces) == normalized
        }
    }

    private static func bestReps(for exerciseName: String, in history: [ExerciseLogEntry]) -> Int {
        matchingEntries(exerciseName: exerciseName, in: history)
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .map { $0.reps }
            .max() ?? 0
    }

    private static func bestWeight(in history: [ExerciseLogEntry]) -> Double {
        history
            .flatMap { $0.sets }
            .filter { !$0.isWarmup }
            .compactMap { $0.weightKg }
            .max() ?? 0
    }
}
