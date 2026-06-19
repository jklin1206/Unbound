import Foundation

extension DailyWorkoutResolver {
    static func adjustedWorkout(
        _ workout: Workout,
        for skillBlocks: [TrainingBlock],
        modifierContext: DailyWorkoutModifierContext
    ) -> Workout {
        var adjusted = substitutedWorkout(workout, modifierContext: modifierContext)
        adjusted = trialPrepWorkout(adjusted, modifierContext: modifierContext)
        adjusted = taperedWorkout(adjusted, for: skillBlocks)
        adjusted = deloadedWorkout(adjusted, modifierContext: modifierContext)
        adjusted = shortSessionWorkout(adjusted, modifierContext: modifierContext)
        return adjusted
    }

    private static func substitutedWorkout(
        _ workout: Workout,
        modifierContext: DailyWorkoutModifierContext
    ) -> Workout {
        guard modifierContext.hasModifiers else { return workout }

        var copy = workout
        let originalExclusions = Set(workout.mainExercises.flatMap(exclusionNames))
        var usedNames: Set<String> = []
        copy.mainExercises = workout.mainExercises.map { exercise in
            let excluded = originalExclusions.union(usedNames)
            let uniqueReplacement = replacement(
                for: exercise,
                modifierContext: modifierContext,
                additionalExcludedNames: excluded
            )
            let fallbackReplacement = replacement(
                for: exercise,
                modifierContext: modifierContext,
                additionalExcludedNames: []
            )
            guard let replacement = uniqueReplacement ?? fallbackReplacement else {
                usedNames.formUnion(exclusionNames(for: exercise))
                return exercise
            }
            var adjusted = exercise
            adjusted.name = replacement.displayName
            adjusted.muscleGroups = replacement.muscleGroups
            adjusted.substitution = exercise.name
            adjusted.notes = appendNote("Adjusted for today's modifiers.", to: exercise.notes)
            usedNames.formUnion(exclusionNames(for: replacement))
            return adjusted
        }
        return copy
    }

    private static func trialPrepWorkout(
        _ workout: Workout,
        modifierContext: DailyWorkoutModifierContext
    ) -> Workout {
        guard !modifierContext.trialPrepMovementIds.isEmpty else { return workout }

        var copy = workout
        for movementId in modifierContext.trialPrepMovementIds {
            guard let definition = MovementCatalog.definition(for: movementId),
                  !containsMovement(definition, in: copy.mainExercises),
                  isCompatible(definition, modifierContext: modifierContext)
            else {
                continue
            }
            copy.mainExercises.append(trialPrepExercise(for: definition))
        }
        return copy
    }

    private static func deloadedWorkout(
        _ workout: Workout,
        modifierContext: DailyWorkoutModifierContext
    ) -> Workout {
        guard let rawFactor = modifierContext.deloadFactor else { return workout }
        let factor = min(1, max(0.25, rawFactor))

        var copy = workout
        copy.mainExercises = workout.mainExercises.map { exercise in
            var adjusted = exercise
            adjusted.sets = max(1, Int((Double(exercise.sets) * factor).rounded(.down)))
            adjusted.rpe = exercise.rpe.map { max(5, $0 - 1) }
            adjusted.notes = appendNote("Deload modifier applied.", to: exercise.notes)
            return adjusted
        }
        return copy
    }

    private static func shortSessionWorkout(
        _ workout: Workout,
        modifierContext: DailyWorkoutModifierContext
    ) -> Workout {
        guard modifierContext.shortSessionActive,
              workout.mainExercises.count > 3
        else { return workout }

        var copy = workout
        let primary = workout.mainExercises.filter(isPrimaryExercise)
        let accessory = workout.mainExercises.filter { !isPrimaryExercise($0) }
        let kept = Array((primary + accessory).prefix(3))
        copy.mainExercises = kept.map { exercise in
            var adjusted = exercise
            adjusted.notes = appendNote("Short mode kept this exercise; lower-priority work was cut for today.", to: exercise.notes)
            return adjusted
        }
        copy.estimatedMinutes = min(workout.estimatedMinutes, 30)
        copy.notes = appendNote("Short mode active: compounds first, accessories trimmed.", to: workout.notes)
        return copy
    }

    private static func isPrimaryExercise(_ exercise: Exercise) -> Bool {
        guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else {
            return false
        }
        switch definition.movementSlot {
        case .squat, .hinge, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull:
            return true
        case .arms, .core, .calves, .carry, .cardio, .mobility, .routine, .skill:
            return false
        }
    }

    private static func taperedWorkout(_ workout: Workout, for skillBlocks: [TrainingBlock]) -> Workout {
        let overlapSlots = Set(skillBlocks.flatMap(overlapSlots(for:)))
        guard !overlapSlots.isEmpty else { return workout }

        var copy = workout
        var taperedSlots = Set<MovementSlot>()
        copy.mainExercises = workout.mainExercises.map { exercise in
            guard let definition = MovementCatalog.canonicalExercise(named: exercise.name),
                  overlapSlots.contains(definition.movementSlot),
                  !taperedSlots.contains(definition.movementSlot),
                  exercise.sets > 1
            else {
                return exercise
            }

            taperedSlots.insert(definition.movementSlot)
            var adjusted = exercise
            adjusted.sets = max(1, exercise.sets - 1)
            adjusted.notes = appendSkillModifierNote(to: exercise.notes)
            return adjusted
        }
        return copy
    }

    private static func containsMovement(_ definition: MovementDefinition, in exercises: [Exercise]) -> Bool {
        exercises.contains { exercise in
            guard let existing = MovementCatalog.canonicalExercise(named: exercise.name) else {
                return MovementCatalog.normalized(exercise.name) == MovementCatalog.normalized(definition.displayName)
            }
            return existing.id == definition.id
                || existing.rankStandardMovementId == definition.rankStandardMovementId
        }
    }

    private static func trialPrepExercise(for definition: MovementDefinition) -> Exercise {
        Exercise(
            id: "trial-prep-\(definition.id)",
            name: definition.canonicalExerciseName ?? definition.displayName,
            muscleGroups: definition.muscleGroups,
            sets: 2,
            reps: trialPrepTarget(for: definition.defaultMetric),
            restSeconds: 90,
            rpe: 7,
            notes: "Trial prep modifier.",
            substitution: nil
        )
    }

    private static func trialPrepTarget(for metric: TrainingMetricKind) -> String {
        switch metric {
        case .reps: return "8"
        case .holdSeconds: return "30s"
        case .durationSeconds: return "300s"
        case .distanceMeters: return "400m"
        case .calories: return "30 cal"
        }
    }

    private static func overlapSlots(for block: TrainingBlock) -> [MovementSlot] {
        var slots = Set<MovementSlot>()

        for prescription in block.prescriptions {
            let resolved = MovementResolver.resolve(prescription.exerciseName)
            if let definition = MovementCatalog.definition(for: resolved.movementId),
               definition.movementSlot != .skill {
                slots.insert(definition.movementSlot)
            }
        }

        if slots.isEmpty, let skillId = block.skillId, let node = SkillGraph.shared.node(id: skillId) {
            slots.formUnion(defaultSlots(for: node.cluster))
        }

        return Array(slots)
    }

    private static func defaultSlots(for cluster: SkillCluster) -> [MovementSlot] {
        switch cluster {
        case .pullingPower:
            return [.verticalPull]
        case .calisthenicControl:
            return [.horizontalPush]
        case .handstand, .handstandPushup, .oneArmHandstand:
            return [.verticalPush]
        case .planche:
            return [.horizontalPush, .verticalPush]
        case .legDominance:
            return [.squat]
        case .coreLever:
            return [.core]
        case .conditioning:
            return [.cardio, .carry]
        }
    }

    private static func appendSkillModifierNote(to existing: String?) -> String {
        appendNote("Volume tapered for scheduled skill work.", to: existing)
    }
}
