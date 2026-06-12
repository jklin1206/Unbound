import Foundation

// MARK: - Workout-level modifier pipeline

extension DailyWorkoutResolver {
    static func substitutedWorkout(
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

    static func trialPrepWorkout(
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

    static func deloadedWorkout(
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

    static func shortSessionWorkout(
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

    static func isPrimaryExercise(_ exercise: Exercise) -> Bool {
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
}
