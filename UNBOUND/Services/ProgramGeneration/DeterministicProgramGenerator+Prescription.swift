import Foundation

extension DeterministicProgramGenerator {
    static func toExercise(
        definition: MovementDefinition,
        input: ProgramGeneratorInput,
        blockType: BlockType
    ) -> Exercise {
        let resolution = progressionResolution(for: definition, input: input)
        let definition = resolution.definition
        let state = resolution.state
        let primary = isPrimaryMovement(definition)
        let basePrescription = prescription(
            for: blockType,
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

    static func blockType(forDayNumber dayNumber: Int, input: ProgramGeneratorInput) -> BlockType {
        if input.calibration.requiresLearningWeek { return .deload }
        let dayInArc = ((max(1, dayNumber) - 1) % standardArcDurationDays) + 1
        switch dayInArc {
        case 1...14:
            return .accumulation
        case 15...21:
            return .intensification
        case 22...24:
            return input.experience == .never ? .intensification : .realization
        default:
            return .deload
        }
    }

    static func prescription(
        for blockType: BlockType,
        state: ProgressionState?,
        isPrimary: Bool,
        fallbackRPE: Int,
        definition: MovementDefinition,
        input: ProgramGeneratorInput
    ) -> GeneratedPrescription {
        if usesCalisthenicsPrescription(definition: definition, input: input) {
            return calisthenicsPrescription(
                for: blockType,
                state: state,
                isPrimary: isPrimary,
                fallbackRPE: fallbackRPE,
                definition: definition
            )
        }

        switch blockType {
        case .accumulation:
            let reps = state.map { "\($0.targetRepMin)-\($0.targetRepMax)" } ?? "8-12"
            return (
                sets: isPrimary ? 4 : 3,
                reps: reps,
                restSeconds: isPrimary ? 120 : 75,
                rpe: max(7, state?.targetRPE ?? fallbackRPE),
                note: "Volume focus. Leave 2 reps in reserve."
            )
        case .intensification:
            let reps = state.map { "\($0.targetRepMin)-\($0.targetRepMax)" } ?? (isPrimary ? "5-8" : "8-10")
            return (
                sets: isPrimary ? 4 : 3,
                reps: reps,
                restSeconds: isPrimary ? 150 : 90,
                rpe: max(8, state?.targetRPE ?? 8),
                note: "Load focus. Add weight only if bar speed and form stay clean."
            )
        case .realization, .peaking:
            let reps = state.map { "\($0.targetRepMin)-\($0.targetRepMax)" } ?? (isPrimary ? "3-5" : "6-8")
            return (
                sets: isPrimary ? 3 : 2,
                reps: reps,
                restSeconds: isPrimary ? 180 : 90,
                rpe: max(blockType == .peaking ? 9 : 8, state?.targetRPE ?? 0),
                note: "Quality focus. No grinders; stop before form breaks."
            )
        case .deload:
            return (
                sets: isPrimary ? 2 : 2,
                reps: "8 easy",
                restSeconds: 60,
                rpe: 6,
                note: "Deload. Move well and keep reps easy."
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
        for blockType: BlockType,
        state: ProgressionState?,
        isPrimary: Bool,
        fallbackRPE: Int,
        definition: MovementDefinition
    ) -> GeneratedPrescription {
        if definition.defaultMetric == .holdSeconds || definition.defaultMetric == .durationSeconds {
            switch blockType {
            case .accumulation:
                return (
                    sets: isPrimary ? 4 : 3,
                    reps: "15-25s",
                    restSeconds: isPrimary ? 105 : 75,
                    rpe: max(7, state?.targetRPE ?? fallbackRPE),
                    note: "Accumulate clean time. End the set when shape, shoulder position, or breathing breaks."
                )
            case .intensification:
                return (
                    sets: isPrimary ? 4 : 3,
                    reps: "10-20s",
                    restSeconds: isPrimary ? 120 : 90,
                    rpe: 8,
                    note: "Harder variation, shorter holds. Keep the line strict before extending time."
                )
            case .realization, .peaking:
                return (
                    sets: isPrimary ? 3 : 2,
                    reps: "8-15s",
                    restSeconds: isPrimary ? 150 : 90,
                    rpe: blockType == .peaking ? 9 : 8,
                    note: "Proof-quality holds only. Stop the attempt the moment position drifts."
                )
            case .deload:
                return (
                    sets: 2,
                    reps: "10-20s easy",
                    restSeconds: 60,
                    rpe: 6,
                    note: "Deload. Use an easier shape and leave every hold crisp."
                )
            }
        }

        switch blockType {
        case .accumulation:
            let reps = state.map { "\($0.targetRepMin)-\($0.targetRepMax) clean" } ?? (isPrimary ? "4-8 clean" : "6-10 clean")
            return (
                sets: isPrimary ? 4 : 3,
                reps: reps,
                restSeconds: isPrimary ? 120 : 75,
                rpe: max(7, state?.targetRPE ?? fallbackRPE),
                note: "Build repeatable strict reps. Progress the variation only while range and tempo stay honest."
            )
        case .intensification:
            let reps = state.map { "\($0.targetRepMin)-\($0.targetRepMax) clean" } ?? (isPrimary ? "3-6 clean" : "5-8 clean")
            return (
                sets: isPrimary ? 4 : 3,
                reps: reps,
                restSeconds: isPrimary ? 150 : 90,
                rpe: max(8, state?.targetRPE ?? 8),
                note: "Use a harder leverage or assistance level, not sloppy reps. No kipping unless the skill asks for it."
            )
        case .realization, .peaking:
            let reps = state.map { "\($0.targetRepMin)-\($0.targetRepMax) strict" } ?? (isPrimary ? "2-5 strict" : "4-6 clean")
            return (
                sets: isPrimary ? 3 : 2,
                reps: reps,
                restSeconds: isPrimary ? 180 : 90,
                rpe: max(blockType == .peaking ? 9 : 8, state?.targetRPE ?? 0),
                note: "Proof-quality reps. Stop before partial range, swinging, or joint pain enters."
            )
        case .deload:
            return (
                sets: 2,
                reps: "5-8 easy",
                restSeconds: 60,
                rpe: 6,
                note: "Deload. Use an easier variation and keep every rep smooth."
            )
        }
    }

    static func blockProgrammingNote(for blockType: BlockType) -> String {
        switch blockType {
        case .accumulation:
            return "Accumulation block: build volume and repeatable standards."
        case .intensification:
            return "Intensification block: tighten reps and push load with clean form."
        case .realization:
            return "Realization block: lower volume, higher intent, prove the work."
        case .peaking:
            return "Peaking block: test-specific work only."
        case .deload:
            return "Deload block: reduce fatigue so the next arc lands."
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
