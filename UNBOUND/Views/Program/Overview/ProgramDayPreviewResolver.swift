import Foundation

enum ProgramDayPreviewResolver {
    static func previewWorkout(
        for day: ProgramDay,
        draft: TrainingSessionDraft? = nil
    ) -> Workout? {
        guard !day.isRestDay else { return nil }
        guard let fallback = day.workout else { return nil }
        guard let draft else { return fallback }

        let exercises = previewExercises(from: draft, fallback: fallback.mainExercises)
        guard !exercises.isEmpty else { return fallback }

        return Workout(
            name: draft.title,
            targetMuscleGroups: previewMuscleGroups(from: exercises, fallback: fallback.targetMuscleGroups),
            warmup: fallback.warmup,
            mainExercises: exercises,
            cooldown: fallback.cooldown,
            estimatedMinutes: draft.estimatedMinutes,
            notes: fallback.notes,
            blockType: fallback.blockType
        )
    }

    static func previewExercises(
        from draft: TrainingSessionDraft,
        fallback: [Exercise]
    ) -> [Exercise] {
        let visibleKinds: [TrainingBlockKind] = [.skill, .strength, .custom, .carry, .cardio]
        let prescriptions = visibleKinds.flatMap { kind in
            draft.blocks
                .filter { $0.kind == kind }
                .flatMap(\.prescriptions)
        }
        let uniquePrescriptions = prescriptions.reduce(into: [TrainingBlockPrescription]()) { result, prescription in
            let normalized = MovementCatalog.normalized(prescription.exerciseName)
            guard result.contains(where: { MovementCatalog.normalized($0.exerciseName) == normalized }) == false else {
                return
            }
            result.append(prescription)
        }

        guard !uniquePrescriptions.isEmpty else { return fallback }
        return uniquePrescriptions.map(previewExercise)
    }

    static func previewExercise(from prescription: TrainingBlockPrescription) -> Exercise {
        Exercise(
            id: prescription.id,
            name: prescription.exerciseName,
            muscleGroups: prescription.muscleGroups,
            sets: prescription.sets,
            reps: prescription.displayTargetText,
            restSeconds: prescription.restSeconds,
            rpe: prescription.rpe,
            notes: prescription.notes,
            substitution: nil,
            suggestedWeightKg: prescription.suggestedWeightKg
        )
    }

    static func previewMuscleGroups(
        from exercises: [Exercise],
        fallback: [MuscleGroup]
    ) -> [MuscleGroup] {
        let used = Set(exercises.flatMap(\.muscleGroups))
        let ordered = MuscleGroup.allCases.filter { used.contains($0) }
        return ordered.isEmpty ? fallback : ordered
    }
}
