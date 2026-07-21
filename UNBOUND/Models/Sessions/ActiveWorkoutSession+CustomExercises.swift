import Foundation
import Combine

extension ActiveWorkoutSession {
    func appendCustomExercise(_ custom: CustomExercise) {
        let plannedSets = Self.defaultSetCount(for: custom.classification)
        let isHold = custom.measure == .hold
        let plannedReps = isHold
            ? "\(custom.defaultHoldSeconds)s"
            : "\(custom.defaultRepMin)-\(custom.defaultRepMax)"
        let targetRPE = 8
        let exercise = ActiveExercise(
            id: custom.id.uuidString,
            name: custom.displayName,
            plannedSets: plannedSets,
            plannedReps: plannedReps,
            restSeconds: Self.defaultRestSeconds(for: custom.classification),
            muscleGroups: Self.muscleGroups(for: custom.pattern),
            sets: (0..<plannedSets).map { _ in
                ActiveSet(
                    id: UUID().uuidString,
                    weightKg: nil,
                    reps: nil,
                    rpe: nil,
                    isWarmup: false,
                    logged: false,
                    suggestedReps: isHold ? nil : custom.defaultRepMin,
                    suggestedHoldSeconds: isHold ? custom.defaultHoldSeconds : nil,
                    suggestedRPE: targetRPE,
                    suggestedRestSeconds: Self.defaultRestSeconds(for: custom.classification)
                )
            },
            skipped: false,
            notes: custom.notes ?? "",
            targetRPE: targetRPE,
            substitution: "Custom exercise",
            blockKind: custom.classification == .bodyweightSkill ? .bodyweight : .strength,
            tracksHold: isHold,
            metricKind: isHold ? .holdSeconds : .reps
        )

        objectWillChange.send()
        exercises.append(exercise)
    }

    private static func defaultSetCount(for classification: ExerciseClassification) -> Int {
        switch classification {
        case .upperCompound, .lowerCompound, .bodyweightSkill:
            return 3
        case .accessory:
            return 2
        }
    }

    private static func defaultRestSeconds(for classification: ExerciseClassification) -> Int {
        switch classification {
        case .upperCompound, .lowerCompound:
            return 120
        case .bodyweightSkill:
            return 90
        case .accessory:
            return 75
        }
    }

    private static func muscleGroups(for pattern: MovementPattern) -> [MuscleGroup] {
        switch pattern {
        case .legsQuad:
            return [.quads, .glutes]
        case .legsPosterior:
            return [.hamstrings, .glutes]
        case .calves:
            return [.calves]
        case .pushHorizontal, .pushVertical:
            return [.chest, .shoulders, .triceps]
        case .arms:
            return [.biceps, .triceps]
        case .pullHorizontal, .pullVertical:
            return [.back, .biceps]
        case .core:
            return [.core]
        }
    }
}
