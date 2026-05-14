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

    // MARK: Chunk 3 — block rollover from the Program tab CTA
    //
    // Lightweight rollover used by the "BUILD BLOCK N+1" affordance on
    // ProgramOverviewView. Reads the latest ScanDeltaReport (if any), maps
    // laggingAreas → focused TargetArea seeds for the next block, then
    // generates a new 28-day program at the next block number so arc
    // periodization advances (block 2 → intensification, block 3 → realization).
    //
    // Best-effort persistence: every save uses `try?`. The user must always
    // see the new program even if the network/Supabase write hiccups.

    @MainActor
    static func generateNextBlock(
        currentProgram: TrainingProgram,
        userId: String,
        profile: UserProfile
    ) async -> TrainingProgram? {
        let logger = LoggingService.shared

        // 1. Resolve next block number from persisted block records.
        let previous = await ProgramBlockStore.shared.latestBlock(userId: userId)
        let nextBlockNumber = max((previous?.blockNumber ?? 1) + 1, 2)

        // 2. Fetch latest scan delta report (most recent rescan).
        let deltaReport = await fetchLatestDeltaReport(userId: userId)

        // 3. Merge focus areas. Lagging areas surface from the scan; if any
        // exist they take priority since they're the user's actual gaps.
        // Otherwise fall back to the user's stated profile target areas.
        let mappedFromLagging = mapLaggingAreas(deltaReport?.laggingAreas ?? [])
        let baseTargetAreas = Set(profile.targetAreas ?? [])
        let nextTargetAreas: Set<TargetArea> = mappedFromLagging.isEmpty
            ? baseTargetAreas
            : baseTargetAreas.union(mappedFromLagging)

        // 4. Resolve archetype + supporting profile fields.
        let archetype = profile.preferredArchetype ?? currentProgram.archetype
        let calibrations = await CalibrationService.shared.fetchAll(userId: userId)
        let rank = await RankService.shared.archetypeRank(userId: userId, archetype: archetype)

        // 5. Generate the new program at the next block number.
        let program = LocalProgramGenerator.generate(
            archetype: archetype,
            targetFrequency: profile.targetFrequency,
            equipment: Set(profile.equipment ?? []),
            experience: profile.experience,
            sessionLength: profile.sessionLength,
            exerciseStyles: Set(profile.exerciseStyles ?? []),
            targetAreas: nextTargetAreas,
            goals: Set(profile.goals ?? []),
            obstacles: Set(profile.obstacles ?? []),
            sleepQuality: profile.sleepQuality ?? 5,
            stressLevel: profile.stressLevel ?? 5,
            currentFrequency: profile.currentFrequency,
            commitment: profile.commitment ?? 8,
            displayHandle: profile.displayHandle ?? profile.displayName ?? "",
            age: profile.age ?? 0,
            gender: profile.gender ?? .unspecified,
            heightCm: profile.heightCm ?? 0,
            weightKg: profile.weightKg ?? 0,
            preferences: [],
            progressionStates: [],
            familyStates: [],
            customExercises: [],
            calibrations: calibrations,
            archetypeRank: rank,
            userId: userId,
            blockNumber: nextBlockNumber
        )

        logger.log(
            "Block rollover program generated",
            level: .info,
            context: [
                "programId": program.id,
                "blockNumber": "\(nextBlockNumber)",
                "previousProgramId": currentProgram.id,
                "laggingAreasUsed": "\(mappedFromLagging.count)"
            ]
        )

        // 6. Persist program (Supabase, with local fallback).
        await SupabaseProgramService.shared.saveProgram(program, userId: userId)

        // 7. Persist a ProgramBlock record so the next rollover knows where
        //    we are. Carry forward the cut-mode flag from the previous block
        //    when present so users mid-cut keep cutting.
        let newBlock = ProgramBlock(
            id: UUID().uuidString,
            userId: userId,
            programId: program.id,
            blockNumber: nextBlockNumber,
            startedAt: Date(),
            scanId: deltaReport?.comparisonScanId,
            accessoryBias: previous?.accessoryBias ?? [:],
            cutModeActive: previous?.cutModeActive ?? profile.cutMode.enabled,
            biasRefreshedFromPrevious: false,
            exerciseRotationsThisBlock: []
        )
        await ProgramBlockStore.shared.save(newBlock)

        // 8. Persist current-program pointer locally + on the user row.
        UserDefaults.standard.set(program.id, forKey: "currentProgramId")
        try? await UserService.shared.updateProfile(
            userId: userId,
            fields: ["currentProgramId": program.id]
        )

        return program
    }

    // MARK: Chunk 3 helpers

    /// Pull the most recent scanDeltaReports row for `userId`. Returns nil
    /// when no rescan has produced a comparison yet.
    private static func fetchLatestDeltaReport(userId: String) async -> ScanDeltaReport? {
        do {
            let results: [ScanDeltaReport] = try await DatabaseService.shared.query(
                collection: "scanDeltaReports",
                field: "userId",
                isEqualTo: userId,
                orderBy: "createdAt",
                descending: true,
                limit: 1
            )
            return results.first
        } catch {
            LoggingService.shared.log(
                "Failed to load latest ScanDeltaReport: \(error)",
                level: .warning,
                context: ["userId": userId]
            )
            return nil
        }
    }

    /// Map Gemini-produced lagging-area strings ("core", "legs", "shoulders")
    /// to the canonical TargetArea enum. Unknown labels are dropped silently.
    private static func mapLaggingAreas(_ raw: [String]) -> Set<TargetArea> {
        var mapped: Set<TargetArea> = []
        for area in raw {
            let key = area.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            switch key {
            case "shoulders", "shoulder", "delts": mapped.insert(.shoulders)
            case "chest", "pecs":                  mapped.insert(.chest)
            case "arms", "biceps", "triceps":      mapped.insert(.arms)
            case "core", "abs", "midsection":      mapped.insert(.core)
            case "legs", "quads", "hamstrings":    mapped.insert(.legs)
            case "glutes":                         mapped.insert(.glutes)
            case "back", "lats":                   mapped.insert(.back)
            case "fullbody", "full body", "overall":
                mapped.insert(.fullBody)
            default:
                continue
            }
        }
        return mapped
    }
}
