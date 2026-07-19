import Foundation

/// Four-part loading wave inside each 30-day Arc. The normalized day mapping
/// keeps the deload to roughly one week even though an Arc is not 28 days.
enum ProgramTrainingWave: String, CaseIterable {
    case accumulation
    case build
    case intensification
    case deload

    static func forDay(_ dayNumber: Int?) -> ProgramTrainingWave {
        guard let dayNumber, dayNumber > 0 else { return .accumulation }
        let normalizedIndex = min(3, ((dayNumber - 1) * 4) / Arc.durationDays)
        return allCases[normalizedIndex]
    }

    var blockType: BlockType {
        switch self {
        case .accumulation, .build: return .accumulation
        case .intensification: return .intensification
        case .deload: return .deload
        }
    }

    var loadFactor: Double {
        switch self {
        case .accumulation, .build: return 1
        case .intensification: return 1.025
        case .deload: return 0.85
        }
    }

    func adjustedRepTarget(_ target: Int, state: ProgressionState?) -> Int {
        switch self {
        case .accumulation:
            return target
        case .build:
            return min(target + 1, state?.targetRepMax ?? target + 1)
        case .intensification:
            return max(state?.targetRepMin ?? 1, target - 1)
        case .deload:
            return max(1, state?.targetRepMin ?? target - 2)
        }
    }

    func adjustedHoldTarget(_ target: Int, exerciseKey: String) -> Int {
        switch self {
        case .accumulation, .intensification:
            return target
        case .build:
            return IsometricDurationPolicy.nextTarget(after: target, exerciseKey: exerciseKey)
        case .deload:
            return IsometricDurationPolicy.previousTarget(before: target, exerciseKey: exerciseKey)
        }
    }

    func adjustedSets(_ sets: Int) -> Int {
        self == .deload ? max(2, sets - 1) : sets
    }

    var note: String {
        switch self {
        case .accumulation: return "Wave 1/4: establish clean volume."
        case .build: return "Wave 2/4: build reps or hold time."
        case .intensification: return "Wave 3/4: slightly heavier work with clean reps."
        case .deload: return "Wave 4/4: planned deload with lower load and volume."
        }
    }
}

extension DeterministicProgramGenerator {
    static func progressionState(
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

    static func progressionResolution(
        for definition: MovementDefinition,
        input: ProgramGeneratorInput
    ) -> ProgressionExerciseResolution {
        let baseState = progressionState(for: definition, input: input)
        let bias = baseState?.prescriptionBias
        guard let adjustedDefinition = progressionAdjustedDefinition(
            for: definition,
            input: input,
            bias: bias
        ) else {
            return ProgressionExerciseResolution(
                definition: definition,
                state: baseState,
                bias: bias,
                variationNote: nil
            )
        }

        let adjustedState = progressionState(for: adjustedDefinition, input: input) ?? baseState
        return ProgressionExerciseResolution(
            definition: adjustedDefinition,
            state: adjustedState,
            bias: bias,
            variationNote: variationNote(
                original: definition,
                adjusted: adjustedDefinition,
                bias: bias
            )
        )
    }

    static func progressionAdjustedDefinition(
        for definition: MovementDefinition,
        input: ProgramGeneratorInput,
        bias: ProgressionPrescriptionBias?
    ) -> MovementDefinition? {
        guard let family = definition.progressionFamily,
              let familyState = input.progressionFamilyStates[family] else {
            return nil
        }

        let baseTier = definition.progressionTier ?? familyState.currentTier
        let targetTier: Int
        switch bias {
        case .easier:
            targetTier = max(0, baseTier - 1)
        case .harder:
            targetTier = min(familyState.unlockedTier, baseTier + 1)
        case .hold, .none:
            targetTier = min(max(baseTier, familyState.currentTier), familyState.unlockedTier)
        }

        guard targetTier != baseTier,
              let candidate = MovementCatalog.progressionDefinitions(family: family)
                .first(where: { ($0.progressionTier ?? -1) == targetTier }),
              MovementCatalog.isProgramCompatible(
                candidate,
                style: input.trainingStyle,
                userEquipment: input.equipment
              ) else {
            return nil
        }
        return candidate
    }

    static func overloadAdjustedPrescription(
        _ prescription: GeneratedPrescription,
        state: ProgressionState?,
        bias: ProgressionPrescriptionBias?,
        isPrimary: Bool,
        definition: MovementDefinition
    ) -> GeneratedPrescription {
        guard let state else { return prescription }
        var adjusted = prescription

        switch bias {
        case .easier:
            adjusted.reps = tightenedReps(
                current: adjusted.reps,
                state: state,
                definition: definition
            )
            adjusted.restSeconds = min(240, adjusted.restSeconds + (isPrimary ? 30 : 15))
            if adjusted.rpe > 0 {
                let target = state.targetRPE > 0 ? state.targetRPE - 1 : adjusted.rpe - 1
                adjusted.rpe = max(5, min(adjusted.rpe, target))
            }
            adjusted.note = appendNote(
                "Progression adjusted: easier target after recent grind.",
                to: adjusted.note
            )
        case .harder:
            adjusted.restSeconds = min(240, adjusted.restSeconds + (isPrimary ? 15 : 0))
            adjusted.note = appendNote(
                "Progression adjusted: harder option unlocked; keep every rep strict.",
                to: adjusted.note
            )
        case .hold:
            if state.consecutiveSessionsAtTarget == 1 {
                adjusted.note = appendNote(
                    "Progression hold: repeat one more clean top-range session before adding difficulty.",
                    to: adjusted.note
                )
            }
        case .none:
            break
        }

        return adjusted
    }

    static func tightenedReps(
        current: String,
        state: ProgressionState,
        definition: MovementDefinition
    ) -> String {
        guard definition.defaultMetric == .reps else { return current }
        let lower = state.targetRepMin
        let upper = max(lower, state.targetRepMax - 2)
        guard upper < state.targetRepMax else { return current }
        let suffix = repSuffix(from: current)
        return "\(lower)-\(upper)\(suffix)"
    }

    static func repSuffix(from reps: String) -> String {
        let lower = reps.lowercased()
        if lower.contains("strict") { return " strict" }
        if lower.contains("clean") { return " clean" }
        if lower.contains("easy") { return " easy" }
        return ""
    }

    static func variationNote(
        original: MovementDefinition,
        adjusted: MovementDefinition,
        bias: ProgressionPrescriptionBias?
    ) -> String? {
        switch bias {
        case .easier:
            return "Variation adjusted: \(original.displayName) moved to \(adjusted.displayName) for cleaner reps."
        case .harder:
            return "Variation adjusted: \(adjusted.displayName) selected from unlocked progression."
        case .hold, .none:
            return nil
        }
    }

    static func suggestedWeightKg(
        for state: ProgressionState?,
        bias: ProgressionPrescriptionBias?,
        wave: ProgramTrainingWave = .accumulation
    ) -> Double? {
        guard let state, state.currentWorkingWeightKg > 0 else { return nil }
        let biasFactor = bias == .easier ? 0.95 : 1
        let adjusted = max(0, state.currentWorkingWeightKg * biasFactor * wave.loadFactor)
        return WeightPlatePolicy.snappedSuggestionKilograms(adjusted, exerciseKey: state.exerciseKey)
    }

    static func waveAdjustedPrescription(
        _ prescription: GeneratedPrescription,
        state: ProgressionState?,
        definition: MovementDefinition,
        wave: ProgramTrainingWave
    ) -> GeneratedPrescription {
        var adjusted = prescription
        adjusted.sets = wave.adjustedSets(adjusted.sets)

        if definition.defaultMetric == .holdSeconds || definition.defaultMetric == .durationSeconds {
            let baseSeconds = state?.currentTargetDurationSeconds
                ?? RepRange.lowerBound(adjusted.reps)
                ?? IsometricDurationPolicy.startingTarget(for: definition.displayName)
            let seconds = wave.adjustedHoldTarget(baseSeconds, exerciseKey: definition.displayName)
            adjusted.reps = "\(seconds)s"
        } else if !adjusted.reps.contains("-") {
            let baseReps = RepRange.lowerBound(adjusted.reps) ?? state?.currentTargetReps
            if let baseReps {
                let suffix = repSuffix(from: adjusted.reps)
                adjusted.reps = "\(wave.adjustedRepTarget(baseReps, state: state))\(suffix)"
            }
        }

        adjusted.note = appendNote(wave.note, to: adjusted.note)
        return adjusted
    }
}
