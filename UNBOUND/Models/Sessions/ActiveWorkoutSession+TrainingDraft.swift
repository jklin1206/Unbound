import Foundation
import Combine

extension ActiveWorkoutSession {
    convenience init(trainingDraft draft: TrainingSessionDraft) {
        self.init(workout: TrainingSessionAdapters.workout(from: draft),
                  programId: draft.programId ?? "",
                  dayNumber: draft.dayNumber ?? 0,
                  source: draft.source)
        self.exercises = Self.activeExercises(from: draft)
        markCurrentExerciseStarted(at: startedAt)
    }

    private static func activeExercises(from draft: TrainingSessionDraft) -> [ActiveExercise] {
        draft.blocks.flatMap { block in
            block.prescriptions.map { prescription in
                let definition = movementDefinition(for: prescription)
                let exerciseMetricKind = prescription.target.metricKind(defaultingTo: definition?.defaultMetric)
                let setPlans = prescription.effectiveSetPlans
                return ActiveExercise(
                    id: prescription.id,
                    name: prescription.exerciseName,
                    plannedSets: setPlans.count,
                    plannedReps: prescription.setPlanSummaryText,
                    restSeconds: setPlans.first?.restSeconds ?? prescription.restSeconds,
                    muscleGroups: prescription.muscleGroups,
                    sets: setPlans.map { plan in
                        let metricKind = plan.target.metricKind(defaultingTo: definition?.defaultMetric)
                        return ActiveSet(
                            id: UUID().uuidString,
                            weightKg: nil,
                            reps: nil,
                            rpe: nil,
                            isWarmup: plan.isWarmup,
                            logged: false,
                            suggestedWeightKg: plan.suggestedWeightKg.map {
                                WeightPlatePolicy.snappedSuggestionKilograms($0)
                            },
                            suggestedReps: metricKind == .reps ? plan.target.metricLowerBound : nil,
                            suggestedHoldSeconds: metricKind == .holdSeconds ? plan.target.metricLowerBound : nil,
                            suggestedDurationSeconds: metricKind == .durationSeconds ? plan.target.metricLowerBound : nil,
                            suggestedDistanceMeters: metricKind == .distanceMeters ? plan.target.metricLowerBound : nil,
                            suggestedCalories: metricKind == .calories ? plan.target.metricLowerBound : nil,
                            suggestedRPE: plan.rpe,
                            suggestedRestSeconds: plan.restSeconds
                        )
                    },
                    skipped: false,
                    notes: draft.source == .overallRankTrial ? (prescription.notes ?? "") : "",
                    movementId: prescription.movementId,
                    rankStandardMovementId: prescription.rankStandardMovementId,
                    targetRPE: prescription.rpe,
                    formCues: prescription.notes,
                    substitution: nil,
                    blockKind: block.kind,
                    blockId: block.id,
                    blockTitle: block.title,
                    skillId: block.skillId,
                    selectedRungId: block.selectedRungId,
                    selectedRungSource: block.selectedRungSource,
                    selectedRungReason: block.selectedRungReason,
                    routineId: block.routineId,
                    cardioType: block.cardioType,
                    tracksHold: block.kind == .carry || exerciseMetricKind == .holdSeconds || exerciseMetricKind == .durationSeconds,
                    metricKind: exerciseMetricKind
                )
            }
        }
    }

    private static func movementDefinition(for prescription: TrainingBlockPrescription) -> MovementDefinition? {
        if let movementId = prescription.movementId,
           let definition = MovementCatalog.definition(for: movementId) {
            return definition
        }
        let resolved = MovementResolver.resolve(prescription.exerciseName)
        return MovementCatalog.definition(for: resolved.movementId)
    }
}
