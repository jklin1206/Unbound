import Foundation

extension DeterministicProgramGenerator {
    static func buildWorkout(
        for template: DayTemplate,
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int],
        goal: TrainingGoal,
        sessionIndex: Int = 0,
        dayNumber: Int = 1
    ) -> Workout {
        let compatibleCatalog = movementPool(input: input)
        let wave = ProgramTrainingWave.forDay(dayNumber)

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

        let budgetMinutes = sessionBudgetMinutes(for: input)
        // Primaries anchor every recurrence of this template within the head
        // anchor tier of the score-sorted pool — block-to-block variety cycles
        // the few best-fit lifts, never an arbitrary pool position — and the
        // user's explicit substitute picks are pinned in front of everything.
        // Accessories rotate weekly instead of churning every session.
        let compounds = pinnedFirst(
            anchorTierRotated(
                rotationFiltered(eligiblePool.filter(isPrimaryMovement), input: input),
                by: blockRotationOffset(for: input)
            ),
            input: input
        )
        let accessories = pinnedFirst(
            rotateDefinitions(
                rotationFiltered(eligiblePool.filter { !isPrimaryMovement($0) }, input: input),
                by: weeklyRotationOffset(for: input, sessionIndex: sessionIndex)
            ),
            input: input
        )

        // Compounds: prefer the biased pick first, then the next available
        // distinct entries — covering a second movement pattern (e.g. a
        // vertical push next to a horizontal one) before doubling the first.
        // If compounds is empty (very possible in a pure bodyweight catalog
        // subset), skip — accessories carry the workout.
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
            let primaryCap = budgetMinutes >= 60 ? 3 : 2
            var usedPrimaryKeys: Set<String> = [workoutEquivalenceKey(for: first)]
            var usedSlots: Set<MovementSlot> = [first.movementSlot]
            for pass in 0..<2 where primaries.count < primaryCap {
                for candidate in compounds where primaries.count < primaryCap {
                    let key = workoutEquivalenceKey(for: candidate)
                    guard !usedPrimaryKeys.contains(key) else { continue }
                    if pass == 0, usedSlots.contains(candidate.movementSlot) { continue }
                    usedPrimaryKeys.insert(key)
                    usedSlots.insert(candidate.movementSlot)
                    primaries.append(candidate)
                }
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
            // Skill days serve the skills the user actually engaged in the
            // tree; only fall back to the general skill pool when nothing is
            // engaged yet.
            let skillPool = rotationFiltered(
                eligiblePool.filter { $0.movementSlot == .skill },
                input: input
            )
            let engaged = skillPool.filter {
                matchesEngagedSkills($0, engagedSkillIds: input.engagedSkillIds)
            }
            let skillCap = budgetMinutes >= 60 ? 3 : 2
            let skillPicks = Array((engaged.isEmpty ? skillPool : engaged).prefix(skillCap))
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
        let cooldown = cooldownExercises(for: template)
        let pickedUnique = uniqueWorkoutDefinitions(picked)
        let mainExercises = pickedUnique.map {
            toExercise(definition: $0, input: input, goal: goal, wave: wave)
        }

        // Back-fill toward the time budget: remaining slot-aligned accessories
        // first, then borrowed secondary-slot accessories, then further
        // compounds. Skill movements never enter through back-fill.
        let secondaryPool = rotateDefinitions(
            rotationFiltered(
                compatibleCatalog.filter {
                    secondaryAccessorySlots(for: template).contains($0.movementSlot)
                },
                input: input
            ),
            by: weeklyRotationOffset(for: input, sessionIndex: sessionIndex)
        )
        let expansionCandidates = (accessories + secondaryPool + compounds)
            .filter { $0.movementSlot != .skill }
        let filled = backfilledMainExercises(
            mainExercises,
            alreadyPicked: pickedUnique,
            candidates: expansionCandidates,
            warmup: warmup,
            cooldown: cooldown,
            budgetMinutes: budgetMinutes
        ) {
            toExercise(definition: $0, input: input, goal: goal, wave: wave)
        }
        let compressed = compressedMainExercises(
            filled,
            warmup: warmup,
            cooldown: cooldown,
            budgetMinutes: budgetMinutes
        )
        let estimatedMinutes = estimatedWorkoutMinutes(
            warmup: warmup,
            main: compressed.exercises,
            cooldown: cooldown
        )
        let notes = [
            blockProgrammingNote(for: goal, wave: wave),
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
            blockType: wave.blockType
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
            // Walk the fallback chain so an unfillable slot degrades to a
            // nearby pattern instead of silently shrinking the session.
            for fallbackSlot in slotFallbackChain(for: slot) {
                guard let definition = calibrationPick(
                    slot: fallbackSlot,
                    from: compatibleCatalog,
                    alreadyPicked: picked,
                    input: input,
                    bias: bias
                ) else { continue }
                picked.append(definition)
                break
            }
        }

        if picked.isEmpty {
            picked = Array(compatibleCatalog.prefix(3))
        }

        let budgetMinutes = sessionBudgetMinutes(for: input)
        let warmup = calibrationWarmup(input: input, planName: plan.name)
        let pickedUnique = uniqueWorkoutDefinitions(picked)
        let exercises = pickedUnique.map { definition in
            toCalibrationExercise(definition: definition, input: input)
        }

        // Calibration back-fill adds more standards to learn, never extra
        // sets — every calibration prescription stays a light 2-set probe.
        let calibrationCandidates = compatibleCatalog.filter { definition in
            switch definition.movementSlot {
            case .squat, .hinge, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .core, .arms, .calves:
                return true
            case .skill, .carry, .cardio, .mobility, .routine:
                return false
            }
        }
        let filled = backfilledMainExercises(
            exercises,
            alreadyPicked: pickedUnique,
            candidates: calibrationCandidates,
            warmup: warmup,
            cooldown: [],
            budgetMinutes: budgetMinutes,
            allowSetBumps: false
        ) {
            toCalibrationExercise(definition: $0, input: input)
        }
        let compressed = compressedMainExercises(
            filled,
            warmup: warmup,
            cooldown: [],
            budgetMinutes: budgetMinutes
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
            // Compound patterns anchor to the block so they can be overloaded;
            // accessory slots rotate weekly. Unfillable slots degrade through
            // the fallback chain instead of silently dropping.
            let isCompoundSlot: Bool
            switch slot {
            case .squat, .hinge, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull:
                isCompoundSlot = true
            default:
                isCompoundSlot = false
            }
            let rotationOffset = isCompoundSlot
                ? blockRotationOffset(for: input) + slotOffset
                : weeklyRotationOffset(for: input, sessionIndex: sessionIndex) + slotOffset
            for fallbackSlot in slotFallbackChain(for: slot) {
                guard let definition = slotPick(
                    slot: fallbackSlot,
                    from: eligiblePool,
                    alreadyPicked: picked,
                    input: input,
                    bias: bias,
                    rotationOffset: rotationOffset,
                    anchored: isCompoundSlot
                ) else {
                    continue
                }
                picked.append(definition)
                break
            }
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
            // 3 movements/session fits a short floor-only budget. Rotate all five
            // patterns across the week so a pull lands twice and core stays twice
            // (it was previously over-weighted at every session, with zero pull).
            plans = [
                [.horizontalPush, .horizontalPull, .core],
                [.squat, .hinge, .core],
                [.horizontalPush, .squat, .horizontalPull]
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
        rotationOffset: Int,
        anchored: Bool = false
    ) -> MovementDefinition? {
        let usedKeys = Set(alreadyPicked.map { workoutEquivalenceKey(for: $0) })
        let candidates = catalog
            .filter { $0.movementSlot == slot }
            .filter { !usedKeys.contains(workoutEquivalenceKey(for: $0)) }
        let ordered = rotationFiltered(candidates, input: input)
        let rotated = anchored
            ? anchorTierRotated(ordered, by: rotationOffset)
            : rotateDefinitions(ordered, by: rotationOffset)
        let rotationAware = pinnedFirst(rotated, input: input)
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
