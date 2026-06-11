import Foundation

extension DeterministicProgramGenerator {
    static func buildWorkout(
        for template: DayTemplate,
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int],
        blockType: BlockType,
        sessionIndex: Int = 0
    ) -> Workout {
        let compatibleCatalog = movementPool(input: input)

        // Which muscle groups does this template emphasize? weakPoint days
        // pull from the biased set; everything else uses the template's own
        // groups.
        let templateGroups: Set<MuscleGroup>
        if template == .weakPoint {
            templateGroups = Set(bias.keys)
        } else {
            templateGroups = Set(template.muscleGroups)
        }

        // First pass: use MovementCatalog's programming slot when the day has
        // a clear movement intent. This prevents broad tags like "arms" from
        // leaking push movements into pull slots.
        var eligiblePool = eligibleDefinitions(
            from: compatibleCatalog,
            for: template,
            templateGroups: templateGroups
        )

        // Fallback: if nothing matched (e.g. weakPoint with an empty bias),
        // accept any compatible entry — the MVP bar is a non-empty pool.
        if eligiblePool.isEmpty {
            eligiblePool = compatibleCatalog
        }

        if template != .skill {
            eligiblePool = eligiblePool.filter { $0.movementSlot != .skill }
        }

        let compounds = rotateDefinitions(
            rotationFiltered(eligiblePool.filter(isPrimaryMovement), input: input),
            by: sessionIndex
        )
        let accessories = rotateDefinitions(
            rotationFiltered(eligiblePool.filter { !isPrimaryMovement($0) }, input: input),
            by: sessionIndex
        )

        // Compounds: prefer the biased pick first, then the next available
        // different entry. If compounds is empty (very possible in a pure
        // bodyweight catalog subset), skip — accessories carry the workout.
        var primaries: [MovementDefinition] = []
        let firstPrimary = bias.isEmpty
            ? compounds.first
            : WeakPointBiaser.pickBiased(
                candidates: compounds,
                biasedGroups: bias,
                biasedGroupsFor: { $0.muscleGroups }
            )
        if let first = firstPrimary {
            primaries.append(first)
            if let second = compounds.first(where: { $0 != first }) {
                primaries.append(second)
            }
        }

        // Accessories: take the first 3 from the pool, then bolt on up to 2
        // bias-aligned extras.
        let baseAccessories = Array(accessories.prefix(3))
        let accessoriesBiased = WeakPointBiaser.addAccessories(
            to: baseAccessories,
            from: accessories,
            biasedGroups: bias,
            maxAccessories: bias.isEmpty ? 0 : 2,
            targetGroupsFor: { $0.muscleGroups }
        )

        let variedSlotPicks = fullBodySlotPicks(
            for: template,
            from: eligiblePool,
            input: input,
            bias: bias,
            sessionIndex: sessionIndex
        )

        let pickedForTemplate: [MovementDefinition]
        if !variedSlotPicks.isEmpty {
            pickedForTemplate = variedSlotPicks
        } else if template == .skill {
            let skillPicks = Array(
                rotationFiltered(
                    eligiblePool.filter { $0.movementSlot == .skill },
                    input: input
                )
                .prefix(2)
            )
            let supportPicks = (primaries + accessoriesBiased)
                .filter { $0.movementSlot != .skill }
            pickedForTemplate = skillPicks + supportPicks
        } else {
            pickedForTemplate = primaries + accessoriesBiased
        }

        var picked = pickedForTemplate

        // Safety net: if both primaries and accessories were empty (very
        // unlikely given the fallback above), at least grab the first few
        // entries so mainExercises is never empty.
        if picked.isEmpty {
            picked = Array(rotationFiltered(eligiblePool, input: input).prefix(3))
        }

        let warmup = warmupExercises(for: template, input: input)
        let cooldown = cooldownExercises(for: template, blockType: blockType)
        let mainExercises = uniqueWorkoutDefinitions(picked).map {
            toExercise(definition: $0, input: input, blockType: blockType)
        }
        let compressed = compressedMainExercises(
            mainExercises,
            warmup: warmup,
            cooldown: cooldown,
            budgetMinutes: sessionBudgetMinutes(for: input)
        )
        let estimatedMinutes = estimatedWorkoutMinutes(
            warmup: warmup,
            main: compressed.exercises,
            cooldown: cooldown
        )
        let notes = [
            blockProgrammingNote(for: blockType),
            compressed.note
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        return Workout(
            name: template.displayLabel,
            targetMuscleGroups: Array(templateGroups),
            warmup: warmup,
            mainExercises: compressed.exercises,
            cooldown: cooldown,
            estimatedMinutes: estimatedMinutes,
            notes: notes,
            blockType: blockType
        )
    }

    static func buildCalibrationWorkout(
        sessionIndex: Int,
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int]
    ) -> Workout {
        let compatibleCatalog = movementPool(input: input)
        let plan = calibrationPlan(sessionIndex: sessionIndex, input: input)
        var picked: [MovementDefinition] = []

        for slot in plan.slots {
            guard let definition = calibrationPick(
                slot: slot,
                from: compatibleCatalog,
                alreadyPicked: picked,
                input: input,
                bias: bias
            ) else { continue }
            picked.append(definition)
        }

        if picked.isEmpty {
            picked = Array(compatibleCatalog.prefix(3))
        }

        let warmup = calibrationWarmup(input: input, planName: plan.name)
        let exercises = uniqueWorkoutDefinitions(picked).map { definition in
            toCalibrationExercise(definition: definition, input: input)
        }
        let compressed = compressedMainExercises(
            exercises,
            warmup: warmup,
            cooldown: [],
            budgetMinutes: sessionBudgetMinutes(for: input)
        )
        let muscleGroups = Array(Set(exercises.flatMap(\.muscleGroups)))
        let estimatedMinutes = estimatedWorkoutMinutes(
            warmup: warmup,
            main: compressed.exercises,
            cooldown: []
        )
        let note = [
            "Calibration: find clean working standards at RPE 6-7. Stop with 2-3 reps in reserve; do not max.",
            compressed.note
        ]
        .compactMap { $0 }
        .joined(separator: " ")

        return Workout(
            name: plan.name,
            targetMuscleGroups: muscleGroups.isEmpty ? plan.fallbackMuscleGroups : muscleGroups,
            warmup: warmup,
            mainExercises: compressed.exercises,
            cooldown: [],
            estimatedMinutes: estimatedMinutes,
            notes: note,
            blockType: .deload
        )
    }

    static func calibrationPlan(
        sessionIndex: Int,
        input: ProgramGeneratorInput
    ) -> (name: String, slots: [MovementSlot], fallbackMuscleGroups: [MuscleGroup]) {
        let floorOnly = Equipment.isFloorOnlySelection(Set(input.equipment))
        let bodyweightOnly = input.trainingStyle == .bodyweight || floorOnly
        let plans: [(String, [MovementSlot], [MuscleGroup])]

        if floorOnly {
            plans = [
                (
                    "Calibration: Floor Push + Core Standard",
                    [.horizontalPush, .squat, .core],
                    [.chest, .legs, .core]
                ),
                (
                    "Calibration: Floor Legs + Hinge Standard",
                    [.squat, .hinge, .core],
                    [.legs, .glutes, .core]
                ),
                (
                    "Calibration: Full-Body Floor Standard",
                    [.horizontalPush, .squat, .hinge, .core],
                    [.chest, .legs, .glutes, .core]
                )
            ]
        } else if bodyweightOnly {
            plans = [
                (
                    "Calibration: Push + Pull Standard",
                    [.horizontalPush, .verticalPull, .core],
                    [.chest, .back, .core]
                ),
                (
                    "Calibration: Legs + Control Standard",
                    [.squat, .hinge, .verticalPush, .core],
                    [.legs, .glutes, .shoulders, .core]
                ),
                (
                    "Calibration: Full-Body Standard",
                    [.horizontalPush, .horizontalPull, .squat, .core],
                    [.chest, .back, .legs, .core]
                )
            ]
        } else {
            plans = [
                (
                    "Calibration: Upper Standard",
                    [.horizontalPush, .horizontalPull, .verticalPush, .verticalPull],
                    [.chest, .back, .shoulders, .arms]
                ),
                (
                    "Calibration: Lower Standard",
                    [.squat, .hinge, .core],
                    [.legs, .glutes, .core]
                ),
                (
                    "Calibration: Full-Body Standard",
                    [.squat, .horizontalPush, .verticalPull, .core],
                    [.legs, .chest, .back, .core]
                ),
                (
                    "Calibration: Pull + Hinge Standard",
                    [.hinge, .horizontalPull, .verticalPull, .core],
                    [.back, .lats, .glutes, .core]
                )
            ]
        }

        return plans[sessionIndex % plans.count]
    }

    static func calibrationPick(
        slot: MovementSlot,
        from catalog: [MovementDefinition],
        alreadyPicked: [MovementDefinition],
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int]
    ) -> MovementDefinition? {
        let usedKeys = Set(alreadyPicked.map { workoutEquivalenceKey(for: $0) })
        let candidates = catalog
            .filter { $0.movementSlot == slot }
            .filter { !usedKeys.contains(workoutEquivalenceKey(for: $0)) }

        let rotationAwareCandidates = rotationFiltered(candidates, input: input)
        guard !rotationAwareCandidates.isEmpty else { return nil }
        if !bias.isEmpty,
           let biased = WeakPointBiaser.pickBiased(
               candidates: rotationAwareCandidates,
               biasedGroups: bias,
               biasedGroupsFor: { $0.muscleGroups }
           ) {
            return biased
        }

        return rotationAwareCandidates.first
    }

    static func fullBodySlotPicks(
        for template: DayTemplate,
        from eligiblePool: [MovementDefinition],
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int],
        sessionIndex: Int
    ) -> [MovementDefinition] {
        guard let slots = fullBodySlotPlan(
            for: template,
            input: input,
            sessionIndex: sessionIndex
        ) else {
            return []
        }

        var picked: [MovementDefinition] = []
        for (slotOffset, slot) in slots.enumerated() {
            guard let definition = slotPick(
                slot: slot,
                from: eligiblePool,
                alreadyPicked: picked,
                input: input,
                bias: bias,
                rotationOffset: sessionIndex + slotOffset
            ) else {
                continue
            }
            picked.append(definition)
        }
        return picked
    }

    static func fullBodySlotPlan(
        for template: DayTemplate,
        input: ProgramGeneratorInput,
        sessionIndex: Int
    ) -> [MovementSlot]? {
        guard template == .fullBody else { return nil }

        let floorOnly = Equipment.isFloorOnlySelection(Set(input.equipment))
        let plans: [[MovementSlot]]
        if floorOnly {
            plans = [
                [.horizontalPush, .squat, .core],
                [.squat, .hinge, .core],
                [.horizontalPush, .hinge, .core]
            ]
        } else if input.trainingStyle == .bodyweight {
            plans = [
                [.horizontalPush, .verticalPull, .squat, .core],
                [.verticalPush, .horizontalPull, .hinge, .core],
                [.horizontalPush, .squat, .verticalPull, .core]
            ]
        } else {
            plans = [
                [.horizontalPush, .horizontalPull, .squat, .core],
                [.verticalPush, .verticalPull, .hinge, .core],
                [.horizontalPush, .hinge, .calves, .core]
            ]
        }

        return plans[sessionIndex % plans.count]
    }

    static func slotPick(
        slot: MovementSlot,
        from catalog: [MovementDefinition],
        alreadyPicked: [MovementDefinition],
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int],
        rotationOffset: Int
    ) -> MovementDefinition? {
        let usedKeys = Set(alreadyPicked.map { workoutEquivalenceKey(for: $0) })
        let candidates = catalog
            .filter { $0.movementSlot == slot }
            .filter { !usedKeys.contains(workoutEquivalenceKey(for: $0)) }
        let rotationAware = rotateDefinitions(rotationFiltered(candidates, input: input), by: rotationOffset)
        guard !rotationAware.isEmpty else { return nil }

        let biasedCandidates = rotationAware.filter { containsBiasedGroup($0, bias: bias) }
        if let biased = biasedCandidates.first {
            return biased
        }

        return rotationAware.first
    }

    static func toCalibrationExercise(
        definition: MovementDefinition,
        input: ProgramGeneratorInput
    ) -> Exercise {
        let isBodyweight = input.trainingStyle == .bodyweight
            || definition.equipment.allSatisfy { $0 == .bodyweight || $0 == .pullupBar || $0 == .dipStation || $0 == .rings || $0 == .box }
        let targetReps: String
        let sets: Int
        let restSeconds: Int

        switch definition.defaultMetric {
        case .holdSeconds, .durationSeconds:
            sets = 2
            targetReps = "20s"
            restSeconds = 75
        case .distanceMeters:
            sets = 2
            targetReps = "100m"
            restSeconds = 90
        case .calories:
            sets = 2
            targetReps = "8 cal"
            restSeconds = 90
        case .reps:
            sets = 2
            targetReps = isBodyweight ? "6-10 clean" : "6-8"
            restSeconds = isBodyweight ? 90 : 120
        }

        return Exercise(
            id: UUID().uuidString,
            name: definition.displayName,
            muscleGroups: definition.muscleGroups,
            sets: sets,
            reps: targetReps,
            restSeconds: restSeconds,
            rpe: 7,
            notes: isBodyweight
                ? "Calibration set: use the easiest variation that lets every rep or hold stay strict at RPE 6-7. Stop before form breaks."
                : "Calibration set: choose a load or variation you can control at RPE 6-7. Stop before form breaks.",
            substitution: nil
        )
    }

}
