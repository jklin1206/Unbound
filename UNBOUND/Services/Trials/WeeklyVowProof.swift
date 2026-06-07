import Foundation

enum WeeklyVowTrainingRoute {
    private static let programIdPrefix = TrainingSessionDraft.weeklyVowProgramIdPrefix

    static func programId(for vow: WeeklyVow) -> String {
        "\(programIdPrefix)\(vow.id)"
    }

    static func vowId(from programId: String?) -> String? {
        guard let programId,
              programId.hasPrefix(programIdPrefix)
        else { return nil }
        let id = String(programId.dropFirst(programIdPrefix.count))
        return id.isEmpty ? nil : id
    }

    static func hasCompletedWork(_ performanceLog: PerformanceLog) -> Bool {
        performanceLog.blocks.contains { block in
            if block.exercises.contains(where: hasCompletedExercise) {
                return true
            }

            return (block.durationSeconds ?? 0) > 0
                || (block.distanceMeters ?? 0) > 0
                || (block.calories ?? 0) > 0
        }
    }

    static func satisfiesApexWorkoutCompletion(
        _ performanceLog: PerformanceLog,
        card: WeeklyVowCard
    ) -> Bool {
        let prescriptions = WeeklyVowTrainingBuilder.prescriptions(for: card)
        guard !prescriptions.isEmpty else { return false }
        let exercises = performanceLog.blocks.flatMap(\.exercises)
        guard !exercises.contains(where: \.skipped) else { return false }
        return prescriptions.allSatisfy { prescription in
            exercises.contains { exercise in
                exercise.matches(prescription)
                    && completedSetCount(exercise, satisfying: prescription.target) >= prescription.sets
            }
        }
    }

    private static func hasCompletedExercise(_ exercise: PerformanceExercise) -> Bool {
        guard !exercise.skipped else { return false }
        return exercise.sets.contains { set in
            guard !set.isWarmup else { return false }
            return (set.reps ?? 0) > 0
                || (set.holdSeconds ?? 0) > 0
                || (set.durationSeconds ?? 0) > 0
                || (set.distanceMeters ?? 0) > 0
                || (set.calories ?? 0) > 0
                || (set.weightKg ?? 0) > 0
        }
    }

    private static func completedSetCount(
        _ exercise: PerformanceExercise,
        satisfying target: TrainingTarget
    ) -> Int {
        guard !exercise.skipped else { return 0 }
        return exercise.sets.filter { set in
            guard !set.isWarmup else { return false }
            switch target {
            case .reps(let count):
                return (set.reps ?? 0) >= count
            case .repsRange(let low, _):
                return (set.reps ?? 0) >= low
            case .amrap:
                return (set.reps ?? 0) > 0
                    || (set.holdSeconds ?? 0) > 0
                    || (set.durationSeconds ?? 0) > 0
                    || (set.distanceMeters ?? 0) > 0
                    || (set.calories ?? 0) > 0
            case .holdSeconds(let seconds):
                return max(set.holdSeconds ?? 0, set.durationSeconds ?? 0) >= seconds
            case .distanceMeters(let meters):
                return (set.distanceMeters ?? 0) >= meters
            case .calories(let calories):
                return (set.calories ?? 0) >= calories
            case .timedSeconds(let seconds):
                return max(set.durationSeconds ?? 0, set.holdSeconds ?? 0) >= seconds
            }
        }.count
    }
}

extension PerformanceExercise {
    func matches(_ prescription: TrainingBlockPrescription) -> Bool {
        if let movementId, let prescriptionMovementId = prescription.movementId, movementId == prescriptionMovementId {
            return true
        }
        if let rankStandardMovementId,
           let prescriptionRankStandardMovementId = prescription.rankStandardMovementId,
           rankStandardMovementId == prescriptionRankStandardMovementId {
            return true
        }
        return MovementCatalog.normalized(name) == MovementCatalog.normalized(prescription.exerciseName)
    }
}

extension WeeklyVowsService {
    static func savedWorkSatisfiesProof(
        _ performanceLog: PerformanceLog,
        vow: WeeklyVow,
        bodyweightKg: Double
    ) -> Bool {
        if vow.chosenCard.kind == .apex {
            return WeeklyVowTrainingRoute.satisfiesApexWorkoutCompletion(
                performanceLog,
                card: vow.chosenCard
            )
        }

        switch vow.chosenCard.capstone.evaluation {
        case .manualClaim, .liveTimer:
            return true
        case .autoFromLog(let criterion):
            return TierCriterionEvaluator.satisfied(
                criterion: criterion,
                history: performanceLog.weeklyVowExerciseHistory,
                bodyweightKg: bodyweightKg
            )
        }
    }
}

extension PerformanceLog {
    var weeklyVowExerciseHistory: [ExerciseLogEntry] {
        blocks.flatMap { block in
            block.exercises.map { exercise in
                ExerciseLogEntry(
                    id: exercise.id,
                    exerciseName: exercise.name,
                    movementId: exercise.movementId,
                    rankStandardMovementId: exercise.rankStandardMovementId,
                    plannedSets: exercise.plannedSets,
                    plannedReps: exercise.plannedTarget,
                    sets: exercise.sets.map { set in
                        SetLog(
                            id: set.id,
                            setNumber: set.setNumber,
                            weightKg: set.weightKg,
                            reps: set.reps ?? 0,
                            rpe: set.rpe,
                            isWarmup: set.isWarmup,
                            durationSeconds: set.holdSeconds ?? set.durationSeconds,
                            qualityFlags: set.qualityFlags,
                            notes: set.notes
                        )
                    },
                    skipped: exercise.skipped,
                    notes: exercise.notes
                )
            }
        }
    }
}
