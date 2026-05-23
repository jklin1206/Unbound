// UNBOUND/Services/ProgramGeneration/DeterministicProgramGenerator.swift
import Foundation

/// Pure-function input bundle for program generation. No IO, no services.
///
/// All fields needed to produce a deterministic 14-day `TrainingProgram` live
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
    var focusAreas: [FocusArea]
    var cutModeActive: Bool
    let trainingFeedbackMode: TrainingFeedbackMode
    let progressionStates: [String: ProgressionState]
    let previousBlock: ProgramBlock?
    let weightKg: Double
    let heightCm: Double
    let age: Int
    let sex: BiologicalSex
    let blockStartDate: Date
    var exercisePreferences: [ExercisePreference] = []
}

/// Task 2.5 — turns a `ProgramGeneratorInput` into a fully-formed 14-day
/// `TrainingProgram`. No AI, no remote calls — every decision is a pure
/// function of the input struct. Equipment filtering refinement (2.6) and
/// rationale expansion (2.7) come in follow-up tasks; this generator is
/// intentionally MVP: it schedules days, picks a small exercise pool per
/// training day, and stamps sensible nutrition/recovery defaults.
enum DeterministicProgramGenerator {

    enum GeneratorError: Error {
        case unexpected(String)
    }

    static func generate(input: ProgramGeneratorInput) throws -> TrainingProgram {
        let bias = WeakPointBiaser.bias(from: input.focusAreas)
        let split = SplitLookup.split(buildIdentity: input.buildIdentity, frequency: input.targetFrequency)

        let days = try scheduleDays(
            split: split,
            trainingDays: input.trainingDays,
            blockStartDate: input.blockStartDate,
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

        let nutritionPlan = NutritionPlan(
            dailyCalories: macros.calories,
            proteinGrams: macros.proteinG,
            carbsGrams: macros.carbsG,
            fatGrams: macros.fatG,
            mealCount: 4,
            meals: [],
            hydrationLiters: 3.0,
            supplements: [],
            notes: "",
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

        return TrainingProgram(
            id: UUID().uuidString,
            scanId: input.scanId ?? "",
            analysisId: input.analysisId ?? "",
            userId: input.userId,
            createdAt: input.blockStartDate,
            name: "\(input.buildIdentity.displayName) Arc",
            description: "\(input.targetFrequency.numericCount)-day personalized plan.",
            durationDays: 14,
            days: days,
            nutritionPlan: nutritionPlan,
            recoveryPlan: recoveryPlan,
            difficultyLevel: difficultyLevel(for: input.experience),
            requiredEquipment: input.equipment.map(\.rawValue),
            estimatedDailyMinutes: estimatedDailyMinutes(for: input.experience),
            rationale: rationale
        )
    }

    // MARK: — Day scheduling

    private static func scheduleDays(
        split: Split,
        trainingDays: Set<Weekday>,
        blockStartDate: Date,
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int]
    ) throws -> [ProgramDay] {
        let cal = Calendar(identifier: .gregorian)
        let templates = split.trainingDayTemplates
        var cursor = 0
        var result: [ProgramDay] = []

        for i in 0..<14 {
            guard let date = cal.date(byAdding: .day, value: i, to: blockStartDate),
                  let weekday = Weekday(from: date, calendar: cal) else {
                throw GeneratorError.unexpected("bad date math at offset \(i)")
            }
            let dayNumber = i + 1

            if trainingDays.contains(weekday) && !templates.isEmpty {
                let template = templates[cursor % templates.count]
                cursor += 1
                let workout = buildWorkout(for: template, input: input, bias: bias)
                let label = labelFor(template: template, bias: bias)
                result.append(ProgramDay(
                    id: UUID().uuidString,
                    dayNumber: dayNumber,
                    label: label,
                    isRestDay: false,
                    workout: workout,
                    nutritionOverride: nil,
                    recoveryActivities: []
                ))
            } else {
                result.append(ProgramDay(
                    id: UUID().uuidString,
                    dayNumber: dayNumber,
                    label: "Rest",
                    isRestDay: true,
                    workout: nil,
                    nutritionOverride: nil,
                    recoveryActivities: restDayActivities()
                ))
            }
        }
        return result
    }

    // MARK: — Workout building (MVP — refined in 2.6/2.7)

    private static func buildWorkout(
        for template: DayTemplate,
        input: ProgramGeneratorInput,
        bias: [MuscleGroup: Int]
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

        let compounds = eligiblePool.filter(isPrimaryMovement)
        let accessories = eligiblePool.filter { !isPrimaryMovement($0) }

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
            picked = Array(eligiblePool.prefix(3))
        }

        let mainExercises = uniqueDefinitions(picked).map { toExercise(definition: $0, input: input) }

        return Workout(
            name: template.displayLabel,
            targetMuscleGroups: Array(templateGroups),
            warmup: [],
            mainExercises: mainExercises,
            cooldown: [],
            estimatedMinutes: 45 + (mainExercises.count * 5),
            notes: nil,
            blockType: .accumulation
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

    private static func toExercise(definition: MovementDefinition, input: ProgramGeneratorInput) -> Exercise {
        let key = (definition.canonicalExerciseName ?? definition.displayName).lowercased()
        let state = input.progressionStates[key]
        let sets = 3
        let reps: String
        if let s = state {
            reps = "\(s.targetRepMin)-\(s.targetRepMax)"
        } else {
            reps = "8-12"
        }
        let rpeDefault = input.trainingFeedbackMode.defaultTargetRPE
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
            sets: sets,
            reps: reps,
            restSeconds: 90,
            rpe: rpeDefault > 0 ? rpeDefault : nil,
            notes: nil,
            substitution: substitute?.displayName
        )
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

    private static func difficultyLevel(for experience: Experience) -> DifficultyLevel {
        switch experience {
        case .never, .tried: return .beginner
        case .used: return .intermediate
        case .current: return .advanced
        }
    }

    private static func estimatedDailyMinutes(for experience: Experience) -> Int {
        switch experience {
        case .never, .tried: return 45
        case .used: return 60
        case .current: return 75
        }
    }
}
