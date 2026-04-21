// UNBOUND/Services/ProgramGeneration/BlockRolloverService.swift
import Foundation

/// Orchestrates the 2-week-block rollover: reads previous state, applies the
/// gated bias-refresh rule, identifies stale exercises to rotate, generates
/// the next `TrainingProgram`, and persists a new `ProgramBlock`.
///
/// Split into two surfaces:
/// - `resolveRollover(...)` — pure-function decision: bias + rotation list.
///   Easily unit-testable.
/// - `performRollover(...)` — full flow that reads services and writes state.
///   Smoke-verified manually in the app.
enum BlockRolloverService {

    struct Resolution: Equatable {
        let accessoryBiasResult: AccessoryBiasRefreshRule.Result
        let exercisesToRotate: [String]
    }

    // MARK: Pure resolution

    /// Given the previous block, new scan focus, and per-exercise history,
    /// decide the new block's bias and which exercises to rotate.
    static func resolveRollover(
        previousBlock: ProgramBlock?,
        newFocusAreas: [FocusArea],
        exerciseHistory: [String: ExerciseRefreshRule.ExerciseHistory],
        cutModeActive: Bool
    ) -> Resolution {
        let biasResult = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: newFocusAreas,
            previousBlock: previousBlock
        )
        let toRotate = exerciseHistory.values
            .filter { ExerciseRefreshRule.shouldRotate(history: $0) }
            .map(\.exerciseKey)
            .sorted() // stable output for tests and persistence

        return Resolution(
            accessoryBiasResult: biasResult,
            exercisesToRotate: toRotate
        )
    }

    // MARK: Full flow (integration)

    enum RolloverError: Error {
        case missingProfileInputs
        case generationFailed(Error)
    }

    /// Full rollover: generates a new program and persists a new ProgramBlock.
    /// Called at block boundary (day 14 → day 15). Not unit-tested here —
    /// verified manually via the app's rollover UX.
    @discardableResult
    static func performRollover(
        userId: String,
        profile: UserProfile,
        analysis: BodyAnalysis?,
        scan: ScanSession?
    ) async throws -> TrainingProgram {
        guard let archetype = profile.preferredArchetype,
              let experience = profile.experience,
              let frequency = profile.targetFrequency,
              let trainingDays = profile.trainingDays, !trainingDays.isEmpty,
              let weight = profile.weightKg,
              let height = profile.heightCm,
              let age = profile.age,
              let sex = profile.biologicalSex else {
            throw RolloverError.missingProfileInputs
        }

        let previous = await ProgramBlockStore.shared.latestBlock(userId: userId)
        let focusAreas = analysis?.focusAreas ?? []

        // Exercise history is stubbed for MVP — rotation fires once we have
        // sufficient block records + logged workouts to build real history.
        let exerciseHistory: [String: ExerciseRefreshRule.ExerciseHistory] = [:]

        let resolution = resolveRollover(
            previousBlock: previous,
            newFocusAreas: focusAreas,
            exerciseHistory: exerciseHistory,
            cutModeActive: profile.cutMode.enabled
        )

        let style = profile.trainingStyleOverride ?? TrainingStyle.default(for: archetype)
        let feedback = profile.trainingFeedbackMode ?? TrainingFeedbackMode.default(for: experience)

        // Progression state lookup is also stubbed for MVP — hooks in once we
        // have a ProgressionStateStore aggregate API. Empty dict is safe: the
        // generator will seed reasonable defaults on first prescription.
        let progressionStates: [String: ProgressionState] = [:]

        let input = ProgramGeneratorInput(
            userId: userId,
            scanId: scan?.id,
            analysisId: analysis?.id,
            archetype: archetype,
            trainingStyle: style,
            equipment: profile.equipment ?? [.bodyweight],
            targetFrequency: frequency,
            trainingDays: trainingDays,
            experience: experience,
            focusAreas: focusAreas,
            cutModeActive: profile.cutMode.enabled,
            trainingFeedbackMode: feedback,
            progressionStates: progressionStates,
            previousBlock: previous,
            weightKg: weight,
            heightCm: height,
            age: age,
            sex: sex,
            blockStartDate: Date()
        )

        let program: TrainingProgram
        do {
            program = try DeterministicProgramGenerator.generate(input: input)
        } catch {
            throw RolloverError.generationFailed(error)
        }

        let newBlock = ProgramBlock(
            id: UUID().uuidString,
            userId: userId,
            programId: program.id,
            blockNumber: (previous?.blockNumber ?? 0) + 1,
            startedAt: Date(),
            scanId: scan?.id,
            accessoryBias: resolution.accessoryBiasResult.bias,
            cutModeActive: profile.cutMode.enabled,
            biasRefreshedFromPrevious: resolution.accessoryBiasResult.carriedForward,
            exerciseRotationsThisBlock: resolution.exercisesToRotate
        )

        await ProgramBlockStore.shared.save(newBlock)
        return program
    }
}
