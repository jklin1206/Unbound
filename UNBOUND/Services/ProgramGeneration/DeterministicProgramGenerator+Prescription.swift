import Foundation

extension DeterministicProgramGenerator {
    static func toExercise(
        definition: MovementDefinition,
        input: ProgramGeneratorInput,
        goal: TrainingGoal
    ) -> Exercise {
        let resolution = progressionResolution(for: definition, input: input)
        let definition = resolution.definition
        let state = resolution.state
        let primary = isPrimaryMovement(definition)
        let basePrescription = prescription(
            for: goal,
            state: state,
            isPrimary: primary,
            fallbackRPE: input.trainingFeedbackMode.defaultTargetRPE,
            definition: definition,
            input: input
        )
        let prescription = overloadAdjustedPrescription(
            basePrescription,
            state: state,
            bias: resolution.bias,
            isPrimary: primary,
            definition: definition
        )
        let note = [prescription.note, resolution.variationNote]
            .compactMap { $0 }
            .joined(separator: " ")
        let substitute = MovementCatalog.catalogDefaultSubstitute(
            for: definition.displayName,
            style: input.trainingStyle,
            userEquipment: input.equipment,
            excludedNames: Set(input.exercisePreferences.compactMap {
                $0.status == .avoid ? $0.exerciseName : nil
            })
        )

        return Exercise(
            id: UUID().uuidString,
            name: definition.displayName,
            muscleGroups: definition.muscleGroups,
            sets: prescription.sets,
            reps: prescription.reps,
            restSeconds: prescription.restSeconds,
            rpe: prescription.rpe > 0 ? prescription.rpe : nil,
            notes: note.isEmpty ? nil : note,
            substitution: substitute?.displayName,
            suggestedWeightKg: suggestedWeightKg(for: state, bias: resolution.bias)
        )
    }

    static func prescription(
        for goal: TrainingGoal,
        state: ProgressionState?,
        isPrimary: Bool,
        fallbackRPE: Int,
        definition: MovementDefinition,
        input: ProgramGeneratorInput
    ) -> GeneratedPrescription {
        if usesCalisthenicsPrescription(definition: definition, input: input) {
            return calisthenicsPrescription(
                for: goal,
                state: state,
                isPrimary: isPrimary,
                fallbackRPE: fallbackRPE,
                definition: definition
            )
        }

        let classification = ExerciseClassification.classify(exerciseKey: definition.displayName)
        // One number, not a window: the range is the engine's internal rails;
        // the plan shows today's climbing target (bottom of the window when
        // there is no history yet).
        let reps = state.map { "\($0.currentTargetReps)" }
            ?? "\(classification.defaultRepRange(for: goal).lowerBound)"

        // rpe: 0 → `toExercise` nils it → no RPE shown anywhere. Fully RPE-free:
        // intensity is the rep target + the note.
        switch goal {
        case .strength:
            return (
                sets: isPrimary ? 4 : 3,
                reps: reps,
                restSeconds: isPrimary ? 180 : 90,
                rpe: 0,
                note: "Strength. Heavy, clean reps — leave ~1 in reserve. Hit the target and it climbs; keep hitting it and the weight does."
            )
        case .hypertrophy:
            return (
                sets: isPrimary ? 4 : 3,
                reps: reps,
                restSeconds: isPrimary ? 120 : 75,
                rpe: 0,
                note: "Build. Hit the target with ~1–2 in reserve. The target climbs first, then the weight."
            )
        case .skill:
            return (
                sets: isPrimary ? 4 : 3,
                reps: reps,
                restSeconds: isPrimary ? 120 : 75,
                rpe: 0,
                note: "Quality reps. Stop before form breaks; progress the variation before load."
            )
        }
    }

    static func usesCalisthenicsPrescription(
        definition: MovementDefinition,
        input: ProgramGeneratorInput
    ) -> Bool {
        guard input.trainingStyle == .bodyweight else { return false }
        let loadedEquipment: Set<MovementEquipment> = [
            .barbell, .dumbbell, .kettlebell, .cable, .machine, .smithMachine, .sled, .cardioMachine
        ]
        return Set(definition.equipment).isDisjoint(with: loadedEquipment)
    }

    static func calisthenicsPrescription(
        for goal: TrainingGoal,
        state: ProgressionState?,
        isPrimary: Bool,
        fallbackRPE: Int,
        definition: MovementDefinition
    ) -> GeneratedPrescription {
        // HOLD track (isometrics → seconds). Single per-Arc build target; the skill
        // tree makes the *variation* harder over time, not these numbers. RPE-free.
        if definition.defaultMetric == .holdSeconds || definition.defaultMetric == .durationSeconds {
            return (
                sets: isPrimary ? 4 : 3,
                reps: "20s",
                restSeconds: isPrimary ? 105 : 75,
                rpe: 0,
                note: "Accumulate clean time. End the set when shape, shoulder position, or breathing breaks; progress the variation before adding time."
            )
        }

        // REP track (clean reps). Range from progression state, else the goal default.
        let classification = ExerciseClassification.classify(exerciseKey: definition.displayName)
        let repTarget = state.map { $0.currentTargetReps }
            ?? classification.defaultRepRange(for: goal).lowerBound
        let reps = "\(repTarget) clean"
        return (
            sets: isPrimary ? 4 : 3,
            reps: reps,
            restSeconds: isPrimary ? 120 : 90,
            rpe: 0,
            note: "Strict reps only. Progress the variation once range and tempo stay honest at the target."
        )
    }

    static func blockProgrammingNote(for goal: TrainingGoal) -> String {
        switch goal {
        case .strength:
            return "Strength arc: heavy clean reps; add weight at the top of the range."
        case .hypertrophy:
            return "Build arc: chase the top of each rep range, then add weight."
        case .skill:
            return "Skills arc: strict reps and holds; progress the variation before load."
        }
    }

    struct WorkoutCompressionResult {
        var exercises: [Exercise]
        var note: String?
    }

    static func compressedMainExercises(
        _ exercises: [Exercise],
        warmup: [Exercise],
        cooldown: [Exercise],
        budgetMinutes: Int
    ) -> WorkoutCompressionResult {
        guard !exercises.isEmpty else {
            return WorkoutCompressionResult(exercises: exercises, note: nil)
        }

        var compressed = exercises
        let originalCount = compressed.count
        let minimumExerciseCount = min(2, compressed.count)
        var usedCompression = false

        while estimatedWorkoutMinutes(warmup: warmup, main: compressed, cooldown: cooldown) > budgetMinutes,
              compressed.count > minimumExerciseCount,
              let index = compressed.lastIndex(where: { !isPrimaryExercise($0) }) {
            compressed.remove(at: index)
            usedCompression = true
        }

        while estimatedWorkoutMinutes(warmup: warmup, main: compressed, cooldown: cooldown) > budgetMinutes,
              let index = compressed.lastIndex(where: { !isPrimaryExercise($0) && $0.sets > 1 }) {
            compressed[index].sets -= 1
            compressed[index].restSeconds = min(compressed[index].restSeconds, 60)
            usedCompression = true
        }

        while estimatedWorkoutMinutes(warmup: warmup, main: compressed, cooldown: cooldown) > budgetMinutes,
              let index = compressed.lastIndex(where: { $0.restSeconds > 60 }) {
            compressed[index].restSeconds = max(60, compressed[index].restSeconds - 30)
            usedCompression = true
        }

        while estimatedWorkoutMinutes(warmup: warmup, main: compressed, cooldown: cooldown) > budgetMinutes,
              let index = compressed.lastIndex(where: { $0.sets > 2 }) {
            compressed[index].sets -= 1
            usedCompression = true
        }

        if usedCompression {
            compressed = compressed.map { exercise in
                var adjusted = exercise
                adjusted.notes = appendNote(
                    "Compressed to fit the \(budgetMinutes)-minute session window.",
                    to: adjusted.notes
                )
                return adjusted
            }
        }

        let removed = originalCount - compressed.count
        let note: String?
        if usedCompression {
            note = removed > 0
                ? "Compressed to fit \(budgetMinutes)m: removed \(removed) lower-priority accessory\(removed == 1 ? "" : "s") and tightened rest."
                : "Compressed to fit \(budgetMinutes)m: tightened sets and rest while preserving the main pattern."
        } else {
            note = "Built to fit the \(budgetMinutes)-minute session window."
        }

        return WorkoutCompressionResult(exercises: compressed, note: note)
    }
}
