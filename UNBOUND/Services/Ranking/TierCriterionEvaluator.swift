import Foundation

/// Pure: evaluates a single TierCriterion against the user's log history.
/// No state, no I/O. The single source of truth for criterion semantics.
///
/// Exercise-name comparisons are case-insensitive and trim whitespace.
/// Warmup sets are excluded from all calculations.
///
/// NOTE on .seconds: this evaluator still only receives WorkoutLog entries,
/// not SessionLog holdSeconds. The .seconds branch remains false until rank
/// evaluation ingests the skill-session log stream.
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
