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
    /// Training objective — the single driver of rep ranges (replaces the phase
    /// cycle). Defaults to hypertrophy; real call sites derive it from buildIdentity.
    var goal: TrainingGoal = .hypertrophy
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
    var progressionFamilyStates: [String: ProgressionFamilyState] = [:]
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
    static let standardArcDurationDays = Arc.durationDays
    static let calibrationDurationDays = 7
    typealias GeneratedPrescription = (sets: Int, reps: String, restSeconds: Int, rpe: Int, note: String?)

    struct ProgressionExerciseResolution {
        let definition: MovementDefinition
        let state: ProgressionState?
        let bias: ProgressionPrescriptionBias?
        let variationNote: String?
    }

    enum GeneratorError: Error {
        case unexpected(String)
    }

    static func generate(input: ProgramGeneratorInput) throws -> TrainingProgram {
        let bias = WeakPointBiaser.bias(from: input.focusAreas)
        let split = SplitLookup.split(
            buildIdentity: input.buildIdentity,
            frequency: input.targetFrequency,
            trainingStyle: input.trainingStyle
        )
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
                : "\(durationDays)-day personalized Arc built from your schedule and standards.",
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
}
