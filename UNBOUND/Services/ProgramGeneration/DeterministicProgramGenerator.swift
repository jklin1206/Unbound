// UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift
import Foundation

/// Pure-function input bundle for program generation. No IO, no services.
///
/// All fields needed to produce a deterministic `TrainingProgram` live
/// on this struct. Callers (tests, the real onboarding/report pipeline)
/// assemble it from user profile + scan + settings.
struct ProgramGeneratorInput {
    let userId: String
    let scanId: String?
    let analysisId: String?
    /// BuildIdentity derived from AttributeService.
    let buildIdentity: BuildIdentity
    var trainingStyle: TrainingStyle
    var equipment: [Equipment]
    let targetFrequency: TargetFrequency
    let trainingDays: Set<Weekday>
    let experience: Experience
    var sessionLengthMinutes: Int = 45
    var focusAreas: [FocusArea]
    var cutModeActive: Bool
    let trainingFeedbackMode: TrainingFeedbackMode
    var progressionStates: [String: ProgressionState]
    let previousBlock: ProgramBlock?
    var exerciseRotationsToApply: [String] = []
    let weightKg: Double
    let heightCm: Double
    let age: Int
    let sex: BiologicalSex
    var nutritionProfileMissingFields: [String] = []
    let blockStartDate: Date
    var exercisePreferences: [ExercisePreference] = []
    var calibration: ProgramCalibrationInput = .standardReady()
}

struct ProgramCalibrationInput {
    let requiresLearningWeek: Bool
    let knownExerciseKeys: Set<String>

    static func learningWeek(knownExerciseKeys: Set<String> = []) -> ProgramCalibrationInput {
        ProgramCalibrationInput(
            requiresLearningWeek: true,
            knownExerciseKeys: knownExerciseKeys
        )
    }

    static func standardReady(knownExerciseKeys: Set<String> = []) -> ProgramCalibrationInput {
        ProgramCalibrationInput(
            requiresLearningWeek: false,
            knownExerciseKeys: knownExerciseKeys
        )
    }
}

/// Task 2.5 — turns a `ProgramGeneratorInput` into a fully-formed
/// `TrainingProgram`. No AI, no remote calls — every decision is a pure
/// function of the input struct. Equipment filtering refinement (2.6) and
/// rationale expansion (2.7) come in follow-up tasks; this generator is
/// intentionally MVP: it schedules days, picks a small exercise pool per
/// training day, and stamps sensible nutrition/recovery defaults.
enum DeterministicProgramGenerator {
    private static let standardArcDurationDays = Arc.durationDays
    private static let calibrationDurationDays = 7

    enum GeneratorError: Error {
        case unexpected(String)
    }

    static func generate(input: ProgramGeneratorInput) throws -> TrainingProgram {
        let bias = WeakPointBiaser.bias(from: input.focusAreas)
        let split = SplitLookup.split(buildIdentity: input.buildIdentity, frequency: input.targetFrequency)
        let durationDays = input.calibration.requiresLearningWeek
            ? calibrationDurationDays
            : standardArcDurationDays

        let days = try scheduleDays(
            split: split,
            trainingDays: input.trainingDays,
            blockStartDate: input.blockStartDate,
            durationDays: durationDays,
            input: input,
            bias: bias
        )

        let macros = MacroCalculator.macros(
            weightKg: input.weightKg,
            heightCm: input.heightCm,
            age: input.age,
            sex: input.sex,
            frequency: input.targetFrequency,
            cutMode: input.cutModeActive
        )
        let hydrationLiters = personalizedHydrationLiters(weightKg: input.weightKg)
        let nutritionSource = nutritionSourceSummary(missingFields: input.nutritionProfileMissingFields)

        let nutritionPlan = NutritionPlan(
            dailyCalories: macros.calories,
            proteinGrams: macros.proteinG,
            carbsGrams: macros.carbsG,
            fatGrams: macros.fatG,
            mealCount: 4,
            meals: [],
            hydrationLiters: hydrationLiters,
            supplements: [],
            notes: nutritionNotes(missingFields: input.nutritionProfileMissingFields),
            sourceSummary: nutritionSource,
            usesEstimatedProfileDefaults: !input.nutritionProfileMissingFields.isEmpty,
            restDayCalories: max(0, macros.calories - 200),
            restDayProteinGrams: macros.proteinG,
            restDayCarbsGrams: max(0, macros.carbsG - 50),
            restDayFatGrams: macros.fatG
        )

        let recoveryPlan = RecoveryPlan(
            sleepHoursTarget: 8.0,
            restDaysPerWeek: max(0, 7 - input.trainingDays.count),
            activities: [],
            notes: ""
        )

        let rationale = RationaleBuilder.build(input: input, bias: bias, split: split)
        let programId = UUID().uuidString
        let arc = input.calibration.requiresLearningWeek
            ? nil
            : Arc(programId: programId, startDate: input.blockStartDate, state: .active)

        return TrainingProgram(
            id: programId,
            scanId: input.scanId ?? "",
            analysisId: input.analysisId ?? "",
            userId: input.userId,
            createdAt: input.blockStartDate,
            name: input.calibration.requiresLearningWeek ? "Calibration Week" : "\(input.buildIdentity.displayName) Arc",
            description: input.calibration.requiresLearningWeek
                ? "Seven days to find your real working standards before the first Arc."
                : "28-day personalized Arc built from your schedule and standards.",
            durationDays: durationDays,
            days: days,
            nutritionPlan: nutritionPlan,
            recoveryPlan: recoveryPlan,
            difficultyLevel: difficultyLevel(for: input.experience),
            requiredEquipment: input.equipment.map(\.rawValue),
            estimatedDailyMinutes: sessionBudgetMinutes(for: input),
            rationale: rationale,
            arcs: arc.map { [$0] } ?? [],
            currentArcId: arc?.id
        )
    }

    private static func personalizedHydrationLiters(weightKg: Double) -> Double {
        let raw = weightKg * 35 / 1_000
        let clamped = min(max(raw, 1.8), 4.5)
        return (clamped * 10).rounded() / 10
    }

    private static func nutritionSourceSummary(missingFields: [String]) -> String {
        guard !missingFields.isEmpty else {
            return "Based on your profile stats, weekly training frequency, and current goal."
        }
        return "Using default \(missingFields.joined(separator: ", ")) until your profile is completed."
    }

    private static func nutritionNotes(missingFields: [String]) -> String {
        if missingFields.isEmpty {
            return "Starting estimate from your profile stats and weekly training frequency. Adjust after two weeks of weigh-ins, performance, and hunger signals."
        }
        return "Temporary estimate. Complete your \(missingFields.joined(separator: ", ")) to tighten calories and macros before treating them as targets."
    }

    // MARK: — Day scheduling

    private static func scheduleDays(
        split: Split,
        trainingDays: Set<Weekday>,
        blockStartDate: Date,
        durationDays: Int,
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int]
    ) throws -> [ProgramDay] {
        let cal = Calendar(identifier: .gregorian)
        let templates = split.trainingDayTemplates
        var cursor = 0
        var result: [ProgramDay] = []

        for i in 0..<durationDays {
            guard let date = cal.date(byAdding: .day, value: i, to: blockStartDate),
                  let weekday = Weekday(from: date, calendar: cal) else {
                throw GeneratorError.unexpected("bad date math at offset \(i)")
            }
            let dayNumber = i + 1

            if trainingDays.contains(weekday) && !templates.isEmpty {
                let template = templates[cursor % templates.count]
                let sessionIndex = cursor
                cursor += 1
                let workout: Workout
                let label: String
                if input.calibration.requiresLearningWeek {
                    workout = buildCalibrationWorkout(sessionIndex: sessionIndex, input: input, bias: bias)
                    label = workout.name
                } else {
                    let blockType = blockType(forDayNumber: dayNumber, input: input)
                    workout = buildWorkout(for: template, input: input, bias: bias, blockType: blockType)
                    label = labelFor(template: template, bias: bias)
                }
                result.append(ProgramDay(
                    id: UUID().uuidString,
                    dayNumber: dayNumber,
                    label: label,
                    isRestDay: false,
                    workout: workout,
                    sessionRole: sessionRole(for: template, workout: workout),
                    nutritionOverride: nil,
                    recoveryActivities: []
                ))
            } else {
                result.append(ProgramDay(
                    id: UUID().uuidString,
                    dayNumber: dayNumber,
                    label: input.calibration.requiresLearningWeek ? "Calibration Rest" : "Rest",
                    isRestDay: true,
                    workout: nil,
                    sessionRole: .rest,
                    nutritionOverride: nil,
                    recoveryActivities: restDayActivities()
                ))
            }
        }
        return result
    }

    // MARK: — Workout building

    private static func buildWorkout(
        for template: DayTemplate,
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int],
        blockType: BlockType
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

        let compounds = rotationFiltered(eligiblePool.filter(isPrimaryMovement), input: input)
        let accessories = rotationFiltered(eligiblePool.filter { !isPrimaryMovement($0) }, input: input)

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

        var picked = primaries + accessoriesBiased

        // Safety net: if both primaries and accessories were empty (very
        // unlikely given the fallback above), at least grab the first few
        // entries so mainExercises is never empty.
        if picked.isEmpty {
            picked = Array(rotationFiltered(eligiblePool, input: input).prefix(3))
        }

        let warmup = warmupExercises(for: template, input: input)
        let cooldown = cooldownExercises(for: template, blockType: blockType)
        let mainExercises = uniqueDefinitions(picked).map {
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

    private static func buildCalibrationWorkout(
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
        let exercises = uniqueDefinitions(picked).map { definition in
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

    private static func calibrationPlan(
        sessionIndex: Int,
        input: ProgramGeneratorInput
    ) -> (name: String, slots: [MovementSlot], fallbackMuscleGroups: [MuscleGroup]) {
        let bodyweightOnly = input.trainingStyle == .bodyweight || input.equipment == [.bodyweight]
        let plans: [(String, [MovementSlot], [MuscleGroup])] = bodyweightOnly
            ? [
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
            : [
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

        return plans[sessionIndex % plans.count]
    }

    private static func calibrationPick(
        slot: MovementSlot,
        from catalog: [MovementDefinition],
        alreadyPicked: [MovementDefinition],
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int]
    ) -> MovementDefinition? {
        let usedKeys = Set(alreadyPicked.map { $0.canonicalExerciseName ?? $0.id })
        let candidates = catalog
            .filter { $0.movementSlot == slot }
            .filter { !usedKeys.contains($0.canonicalExerciseName ?? $0.id) }

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

    private static func toCalibrationExercise(
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
            targetReps = isBodyweight ? "AMRAP" : "6-8"
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
            notes: "Calibration set: choose a load or variation you can control at RPE 6-7. Stop before form breaks.",
            substitution: nil
        )
    }

    private static func movementPool(input: ProgramGeneratorInput) -> [MovementDefinition] {
        let prefsByKey = preferenceMap(input.exercisePreferences)
        let avoidedNames = Set(input.exercisePreferences.flatMap { pref -> [String] in
            guard pref.status == .avoid else { return [] }
            return [pref.exerciseName, pref.displayName]
        })

        let definitions = MovementCatalog.programDefinitions(
            style: input.trainingStyle,
            userEquipment: input.equipment
        )
        let resolved = definitions.compactMap {
            applyPreference(
                to: $0,
                prefsByKey: prefsByKey,
                avoidedNames: avoidedNames,
                input: input
            )
        }
        return uniqueDefinitions(resolved)
    }

    private static func applyPreference(
        to definition: MovementDefinition,
        prefsByKey: [String: ExercisePreference],
        avoidedNames: Set<String>,
        input: ProgramGeneratorInput
    ) -> MovementDefinition? {
        guard let pref = preference(for: definition, prefsByKey: prefsByKey) else {
            return definition
        }

        switch pref.status {
        case .available:
            return definition
        case .avoid:
            return nil
        case .substitute:
            if let substituteName = pref.substitutePreference,
               let substitute = MovementCatalog.canonicalExercise(named: substituteName),
               substitute.movementSlot == definition.movementSlot,
               MovementCatalog.isProgramCompatible(
                   substitute,
                   style: input.trainingStyle,
                   userEquipment: input.equipment
               ),
               !isAvoided(substitute, prefsByKey: prefsByKey) {
                return substitute
            }

            return MovementCatalog.programAlternatives(
                to: definition.displayName,
                style: input.trainingStyle,
                userEquipment: input.equipment,
                excludedNames: avoidedNames
            ).first { !isAvoided($0, prefsByKey: prefsByKey) }
        }
    }

    private static func preferenceMap(_ preferences: [ExercisePreference]) -> [String: ExercisePreference] {
        var map: [String: ExercisePreference] = [:]
        for pref in preferences {
            map[MovementCatalog.normalized(pref.exerciseName)] = pref
            map[MovementCatalog.normalized(pref.displayName)] = pref
        }
        return map
    }

    private static func preference(
        for definition: MovementDefinition,
        prefsByKey: [String: ExercisePreference]
    ) -> ExercisePreference? {
        if let canonical = definition.canonicalExerciseName,
           let pref = prefsByKey[MovementCatalog.normalized(canonical)] {
            return pref
        }
        return prefsByKey[MovementCatalog.normalized(definition.displayName)]
    }

    private static func isAvoided(
        _ definition: MovementDefinition,
        prefsByKey: [String: ExercisePreference]
    ) -> Bool {
        preference(for: definition, prefsByKey: prefsByKey)?.status == .avoid
    }

    private static func isPrimaryMovement(_ definition: MovementDefinition) -> Bool {
        switch definition.movementSlot {
        case .squat, .hinge, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull:
            return definition.muscleGroups.count > 1
        case .arms, .core, .calves, .carry, .cardio, .mobility, .routine, .skill:
            return false
        }
    }

    private static func eligibleDefinitions(
        from catalog: [MovementDefinition],
        for template: DayTemplate,
        templateGroups: Set<MuscleGroup>
    ) -> [MovementDefinition] {
        if let slots = programSlots(for: template) {
            let slotMatches = catalog.filter { slots.contains($0.movementSlot) }
            if !slotMatches.isEmpty {
                return slotMatches
            }
        }

        return catalog.filter { definition in
            !Set(definition.muscleGroups).intersection(templateGroups).isEmpty
        }
    }

    private static func programSlots(for template: DayTemplate) -> Set<MovementSlot>? {
        switch template {
        case .push:
            return [.horizontalPush, .verticalPush]
        case .pull:
            return [.horizontalPull, .verticalPull]
        case .legs:
            return [.squat, .hinge, .calves]
        case .upper:
            return [.horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .arms]
        case .lower:
            return [.squat, .hinge, .calves, .core]
        case .skill:
            return [.skill, .core, .horizontalPush, .verticalPush, .horizontalPull, .verticalPull]
        case .fullBody, .weakPoint:
            return nil
        case .rest:
            return []
        }
    }

    private static func uniqueDefinitions(_ definitions: [MovementDefinition]) -> [MovementDefinition] {
        var seen: Set<String> = []
        return definitions.filter { definition in
            let key = definition.canonicalExerciseName ?? definition.id
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private static func rotationFiltered(
        _ definitions: [MovementDefinition],
        input: ProgramGeneratorInput
    ) -> [MovementDefinition] {
        let staleKeys = rotationKeys(for: input)
        guard !definitions.isEmpty, !staleKeys.isEmpty else { return definitions }
        let fresh = definitions.filter { !matchesRotation($0, staleKeys: staleKeys) }
        return fresh.isEmpty ? definitions : fresh
    }

    private static func rotationKeys(for input: ProgramGeneratorInput) -> Set<String> {
        let raw = (input.previousBlock?.exerciseRotationsThisBlock ?? []) + input.exerciseRotationsToApply
        return Set(raw.map(MovementCatalog.normalized).filter { !$0.isEmpty })
    }

    private static func matchesRotation(
        _ definition: MovementDefinition,
        staleKeys: Set<String>
    ) -> Bool {
        let rankStandard = MovementCatalog.rankStandard(for: definition)
        let candidates = [
            definition.canonicalExerciseName,
            definition.displayName,
            definition.id,
            rankStandard?.canonicalExerciseName,
            rankStandard?.displayName,
            rankStandard?.id
        ]
        .compactMap { $0 }
        .map(MovementCatalog.normalized)

        return candidates.contains { staleKeys.contains($0) }
    }

    private static func toExercise(
        definition: MovementDefinition,
        input: ProgramGeneratorInput,
        blockType: BlockType
    ) -> Exercise {
        let state = progressionState(for: definition, input: input)
        let primary = isPrimaryMovement(definition)
        let prescription = prescription(
            for: blockType,
            state: state,
            isPrimary: primary,
            fallbackRPE: input.trainingFeedbackMode.defaultTargetRPE
        )
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
            notes: prescription.note,
            substitution: substitute?.displayName
        )
    }

    private static func blockType(forDayNumber dayNumber: Int, input: ProgramGeneratorInput) -> BlockType {
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

    private static func prescription(
        for blockType: BlockType,
        state: ProgressionState?,
        isPrimary: Bool,
        fallbackRPE: Int
    ) -> (sets: Int, reps: String, restSeconds: Int, rpe: Int, note: String?) {
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
            return (
                sets: isPrimary ? 4 : 3,
                reps: isPrimary ? "5-8" : "8-10",
                restSeconds: isPrimary ? 150 : 90,
                rpe: 8,
                note: "Load focus. Add weight only if bar speed and form stay clean."
            )
        case .realization, .peaking:
            return (
                sets: isPrimary ? 3 : 2,
                reps: isPrimary ? "3-5" : "6-8",
                restSeconds: isPrimary ? 180 : 90,
                rpe: blockType == .peaking ? 9 : 8,
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

    private static func blockProgrammingNote(for blockType: BlockType) -> String {
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

    private struct WorkoutCompressionResult {
        var exercises: [Exercise]
        var note: String?
    }

    private static func compressedMainExercises(
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

    private static func warmupExercises(
        for template: DayTemplate,
        input: ProgramGeneratorInput
    ) -> [Exercise] {
        let isAdvancedStrength = input.experience == .current && input.trainingStyle != .bodyweight
        let base: [Exercise]

        switch template {
        case .push:
            base = [
                warmupExercise("Shoulder Dislocates", groups: [.shoulders, .chest, .back], reps: "45s"),
                warmupExercise("Incline Pushup", groups: [.chest, .shoulders, .arms, .core], reps: "8")
            ]
        case .pull:
            base = [
                warmupExercise("Shoulder Dislocates", groups: [.shoulders, .back], reps: "45s"),
                warmupExercise("Band Row", groups: [.back, .lats, .arms], reps: "12")
            ]
        case .legs, .lower:
            base = [
                warmupExercise("World's Greatest Stretch", groups: [.legs, .glutes, .back, .core], reps: "45s"),
                warmupExercise("Bodyweight Squat", groups: [.legs, .glutes, .core], reps: "10")
            ]
        case .upper:
            base = [
                warmupExercise("Shoulder Dislocates", groups: [.shoulders, .chest, .back], reps: "45s"),
                warmupExercise("Band Row", groups: [.back, .lats, .arms], reps: "12")
            ]
        case .fullBody, .weakPoint:
            base = [
                warmupExercise("World's Greatest Stretch", groups: [.legs, .glutes, .back, .core], reps: "45s"),
                warmupExercise("Incline Pushup", groups: [.chest, .shoulders, .arms, .core], reps: "8")
            ]
        case .skill:
            base = [
                warmupExercise("Wrist Prep Flow", groups: [.forearms], reps: "45s"),
                warmupExercise("Hollow Hold", groups: [.core], reps: "20s")
            ]
        case .rest:
            base = []
        }

        guard isAdvancedStrength, let ramp = rampWarmupExercise(for: template) else {
            return base
        }
        return base + [ramp]
    }

    private static func calibrationWarmup(
        input: ProgramGeneratorInput,
        planName: String
    ) -> [Exercise] {
        if planName.localizedCaseInsensitiveContains("lower")
            || planName.localizedCaseInsensitiveContains("legs") {
            return warmupExercises(for: .lower, input: input)
        }
        if planName.localizedCaseInsensitiveContains("pull") {
            return warmupExercises(for: .pull, input: input)
        }
        if planName.localizedCaseInsensitiveContains("upper") {
            return warmupExercises(for: .upper, input: input)
        }
        return warmupExercises(for: .fullBody, input: input)
    }

    private static func cooldownExercises(for template: DayTemplate, blockType: BlockType) -> [Exercise] {
        let breathing = warmupExercise(
            "90/90 Breathing Reset",
            groups: [.core],
            reps: "60s",
            restSeconds: 0,
            notes: "Downshift before you leave."
        )

        let stretch: Exercise
        switch template {
        case .push, .upper:
            stretch = warmupExercise(
                "Doorway Pec Stretch",
                groups: [.chest, .shoulders],
                reps: "45s",
                restSeconds: 0,
                notes: "Open the front line."
            )
        case .pull:
            stretch = warmupExercise(
                "Child's Pose Lat Reach",
                groups: [.back, .lats],
                reps: "45s",
                restSeconds: 0,
                notes: "Easy lat reset."
            )
        case .legs, .lower:
            stretch = warmupExercise(
                "Couch Stretch",
                groups: [.legs, .glutes],
                reps: "45s",
                restSeconds: 0,
                notes: "Hip flexor reset."
            )
        case .skill:
            stretch = warmupExercise(
                "Wrist Flexor Stretch",
                groups: [.forearms],
                reps: "45s",
                restSeconds: 0,
                notes: "Unload the wrists."
            )
        case .fullBody, .weakPoint, .rest:
            stretch = warmupExercise(
                "World's Greatest Stretch",
                groups: [.legs, .glutes, .back, .core],
                reps: "45s",
                restSeconds: 0,
                notes: "Full-body reset."
            )
        }

        return blockType == .deload ? [stretch, breathing] : [breathing, stretch]
    }

    private static func rampWarmupExercise(for template: DayTemplate) -> Exercise? {
        switch template {
        case .push, .upper:
            return warmupExercise("Pushup", groups: [.chest, .shoulders, .arms, .core], sets: 1, reps: "5", restSeconds: 45, notes: "Ramp set before loading.")
        case .pull:
            return warmupExercise("Inverted Row", groups: [.back, .lats, .arms], sets: 1, reps: "6", restSeconds: 45, notes: "Ramp set before loading.")
        case .legs, .lower, .fullBody, .weakPoint:
            return warmupExercise("Bodyweight Squat", groups: [.legs, .glutes, .core], sets: 1, reps: "6", restSeconds: 45, notes: "Ramp set before loading.")
        case .skill, .rest:
            return nil
        }
    }

    private static func warmupExercise(
        _ name: String,
        groups: [MuscleGroup],
        sets: Int = 1,
        reps: String,
        restSeconds: Int = 30,
        notes: String? = "Prep work."
    ) -> Exercise {
        Exercise(
            id: UUID().uuidString,
            name: name,
            muscleGroups: groups,
            sets: sets,
            reps: reps,
            restSeconds: restSeconds,
            rpe: 5,
            notes: notes,
            substitution: nil
        )
    }

    private static func estimatedWorkoutMinutes(
        warmup: [Exercise],
        main: [Exercise],
        cooldown: [Exercise]
    ) -> Int {
        let warmupSeconds = warmup.reduce(0) { $0 + estimatedSeconds(for: $1, defaultWorkSeconds: 30) }
        let mainSeconds = main.reduce(0) { $0 + estimatedSeconds(for: $1, defaultWorkSeconds: 40) }
        let cooldownSeconds = cooldown.reduce(0) { $0 + estimatedSeconds(for: $1, defaultWorkSeconds: 30) }
        let transitionSeconds = max(0, warmup.count + main.count + cooldown.count - 1) * 30
        return max(5, Int(ceil(Double(warmupSeconds + mainSeconds + cooldownSeconds + transitionSeconds) / 60.0)))
    }

    private static func estimatedSeconds(for exercise: Exercise, defaultWorkSeconds: Int) -> Int {
        let workSeconds = durationSeconds(in: exercise.reps) ?? defaultWorkSeconds
        return max(1, exercise.sets) * (workSeconds + max(0, exercise.restSeconds))
    }

    private static func durationSeconds(in reps: String) -> Int? {
        let lower = reps.lowercased()
        guard lower.contains("s") else { return nil }
        let digits = lower.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return Int(String(digits))
    }

    private static func isPrimaryExercise(_ exercise: Exercise) -> Bool {
        guard let definition = MovementCatalog.canonicalExercise(named: exercise.name) else {
            return false
        }
        return isPrimaryMovement(definition)
    }

    private static func sessionBudgetMinutes(for input: ProgramGeneratorInput) -> Int {
        min(90, max(30, input.sessionLengthMinutes))
    }

    private static func appendNote(_ note: String, to existing: String?) -> String {
        guard let existing, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return note
        }
        if existing.localizedCaseInsensitiveContains(note) { return existing }
        return "\(existing) \(note)"
    }

    private static func progressionState(
        for definition: MovementDefinition,
        input: ProgramGeneratorInput
    ) -> ProgressionState? {
        let rankStandard = MovementCatalog.rankStandard(for: definition)
        let keys = [
            definition.canonicalExerciseName,
            definition.displayName,
            rankStandard?.canonicalExerciseName,
            rankStandard?.displayName
        ]
        .compactMap { $0 }
        .map(MovementCatalog.normalized)

        for key in keys {
            if let state = input.progressionStates[key] {
                return state
            }
        }
        return nil
    }

    private static func restDayActivities() -> [RecoveryActivity] {
        [
            RecoveryActivity(
                id: UUID().uuidString,
                name: "Walk",
                description: "20-minute easy walk",
                durationMinutes: 20,
                frequency: "Rest days"
            ),
            RecoveryActivity(
                id: UUID().uuidString,
                name: "Mobility flow",
                description: "Hips + shoulders",
                durationMinutes: 10,
                frequency: "Rest days"
            )
        ]
    }

    private static func labelFor(template: DayTemplate, bias: [MuscleGroup: Int]) -> String {
        guard let biggest = bias.max(by: { $0.value < $1.value }) else {
            return template.displayLabel
        }
        return "\(template.displayLabel) + \(biggest.key.displayName) Bias"
    }

    private static func sessionRole(for template: DayTemplate, workout: Workout) -> SessionRole {
        switch template {
        case .push:
            return .push
        case .pull:
            return .pull
        case .legs:
            return .legs
        case .upper:
            return .upper
        case .lower:
            return .lower
        case .fullBody, .weakPoint:
            return inferredSessionRole(from: workout)
        case .skill:
            return .skillOnly
        case .rest:
            return .rest
        }
    }

    private static func inferredSessionRole(from workout: Workout) -> SessionRole {
        let regions = workout.mainExercises
            .flatMap(\.muscleGroups)
            .map(ProgramBodyRegion.from(muscleGroup:))

        let hasPush = regions.contains(.push) || regions.contains(.shoulders)
        let hasPull = regions.contains(.pull)
        let hasLegs = regions.contains(.legs) || regions.contains(.posterior)
        let hasCore = regions.contains(.core)

        switch (hasPush, hasPull, hasLegs, hasCore) {
        case (true, true, true, _):
            return .fullBody
        case (true, true, false, _):
            return .upper
        case (false, false, true, true), (false, false, true, false):
            return .lower
        case (true, false, false, _):
            return .push
        case (false, true, false, _):
            return .pull
        default:
            return .custom(workout.name)
        }
    }

    private static func difficultyLevel(for experience: Experience) -> DifficultyLevel {
        switch experience {
        case .never, .tried: return .beginner
        case .used: return .intermediate
        case .current: return .advanced
        }
    }

}
