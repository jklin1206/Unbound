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

    struct ProgramBlockProposal: Equatable {
        enum MidBlockPatchPolicy: Equatable {
            case nextBlockOnly

            var title: String {
                switch self {
                case .nextBlockOnly:
                    return "Current block stays locked"
                }
            }

            var detail: String {
                switch self {
                case .nextBlockOnly:
                    return "This checkpoint can inform the next-block review, but it will not rewrite today's workout or body-grade the athlete."
                }
            }
        }

        struct Line: Equatable {
        enum Kind: String {
            case scan
            case focus
            case carryForward
            case rotation
            case rescan
            }

            let kind: Kind
            let title: String
            let detail: String
        }

        let currentBlockNumber: Int
        let nextBlockNumber: Int
        let focusAreas: [FocusArea]
        let scanDeltaReport: ScanDeltaReport?
        let resolution: Resolution
        let shouldPromptRescan: Bool
        let midBlockPatchPolicy: MidBlockPatchPolicy
        let lines: [Line]
    }

    // MARK: Pure resolution

    /// Given the previous block, logged focus, and per-exercise history,
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

    static func proposal(
        currentBlockNumber: Int,
        previousBlock: ProgramBlock?,
        latestDeltaReport: ScanDeltaReport?,
        exerciseHistory: [String: ExerciseRefreshRule.ExerciseHistory] = [:],
        cutModeActive: Bool = false
    ) -> ProgramBlockProposal {
        let focusAreas = focusAreas(from: latestDeltaReport)
        let resolution = resolveRollover(
            previousBlock: previousBlock,
            newFocusAreas: focusAreas,
            exerciseHistory: exerciseHistory,
            cutModeActive: cutModeActive
        )
        let lines = proposalLines(
            delta: latestDeltaReport,
            focusAreas: focusAreas,
            resolution: resolution
        )

        return ProgramBlockProposal(
            currentBlockNumber: max(1, currentBlockNumber),
            nextBlockNumber: max(1, currentBlockNumber) + 1,
            focusAreas: focusAreas,
            scanDeltaReport: latestDeltaReport,
            resolution: resolution,
            shouldPromptRescan: latestDeltaReport == nil,
            midBlockPatchPolicy: .nextBlockOnly,
            lines: lines
        )
    }

    static func analysis(
        from proposal: ProgramBlockProposal,
        userId: String
    ) -> BodyAnalysis? {
        guard let delta = proposal.scanDeltaReport, !proposal.focusAreas.isEmpty else { return nil }
        return BodyAnalysis(
            id: "block-proposal-\(delta.id)",
            scanId: delta.comparisonScanId,
            userId: userId,
            createdAt: delta.createdAt,
            buildIdentitySnapshot: nil,
            overallScore: delta.overall.after,
            muscleAssessments: [],
            proportions: ProportionData(
                shoulderToWaistRatio: nil,
                chestToWaistRatio: nil,
                armToForearmRatio: nil,
                upperToLowerBodyBalance: nil,
                leftRightSymmetry: nil,
                overallProportionScore: 0
            ),
            estimatedBodyFatPercentage: nil,
            estimatedMuscleMassCategory: .average,
            focusAreas: proposal.focusAreas,
            summary: delta.narrative,
            strengths: delta.improvements,
            weaknesses: []
        )
    }

    private static func focusAreas(from delta: ScanDeltaReport?) -> [FocusArea] {
        guard delta != nil else { return [] }
        // Monthly scans are proof + recap. They do not label body parts as
        // lagging and do not create hidden accessory bias. Next-block focus
        // should come from user-selected goals, logged performance, plateaus,
        // equipment, and validated checkpoint signals.
        return []
    }

    private static func proposalLines(
        delta: ScanDeltaReport?,
        focusAreas: [FocusArea],
        resolution: Resolution
    ) -> [ProgramBlockProposal.Line] {
        var lines: [ProgramBlockProposal.Line] = []

        if let delta {
            let improvement = delta.improvements.first?.capitalized
            lines.append(
                ProgramBlockProposal.Line(
                    kind: .scan,
                    title: "Checkpoint recap included",
                    detail: improvement.map { "\($0) is trending up; the next block review can see the latest proof." }
                        ?? "The next block review can use the latest checkpoint without changing today's workout."
                )
            )
        } else {
            lines.append(
                ProgramBlockProposal.Line(
                    kind: .rescan,
                    title: "Checkpoint optional",
                    detail: "You can build the next block from training history now, or save a checkpoint first for a fresh recap."
                )
            )
        }

        if !focusAreas.isEmpty {
            let names = focusAreas.map { $0.muscleGroup.displayName }.joined(separator: " + ")
            lines.append(
                ProgramBlockProposal.Line(
                    kind: .focus,
                    title: "Proposed focus: \(names)",
                    detail: "This biases accessories in the next block only; the completed block stays intact."
                )
            )
        } else if resolution.accessoryBiasResult.carriedForward {
            lines.append(
                ProgramBlockProposal.Line(
                    kind: .carryForward,
                    title: "Carrying current focus",
                    detail: "No meaningful scan priority changed, so the next block keeps the current accessory bias."
                )
            )
        }

        if !resolution.exercisesToRotate.isEmpty {
            lines.append(
                ProgramBlockProposal.Line(
                    kind: .rotation,
                    title: "\(resolution.exercisesToRotate.count) stale exercise rotation\(resolution.exercisesToRotate.count == 1 ? "" : "s")",
                    detail: "Repeated movements can rotate in the next block to keep progress fresh."
                )
            )
        }

        return lines
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
        let buildIdentity = await AttributeService.shared.snapshot(userId: userId, asOf: Date()).buildIdentity
        guard let experience = profile.experience,
              let frequency = profile.targetFrequency,
              let trainingDays = profile.trainingDays, !trainingDays.isEmpty,
              let weight = profile.weightKg,
              let height = profile.heightCm,
              let age = profile.age,
              let sex = profile.biologicalSex else {
            throw RolloverError.missingProfileInputs
        }

        let blocks = await ProgramBlockStore.shared.blocks(userId: userId)
        let previous = blocks.first
        let focusAreas = analysis?.focusAreas ?? []

        var progressionStates: [String: ProgressionState] = [:]
        let fetchedProgressionStates = await ProgressionStateStore.shared.fetchAll(userId: userId)
        for state in fetchedProgressionStates {
            progressionStates[MovementCatalog.normalized(state.exerciseKey)] = state
        }

        let currentProgram = await activeProgram(userId: userId)
        let recentLogs = (try? await WorkoutLogService.shared.fetchRecentLogs(userId: userId, limit: 240)) ?? []
        let familyStates = await ProgressionStateStore.shared.allFamilyStates(userId: userId)
        let exerciseHistory = exerciseHistory(
            previousBlock: previous,
            blocks: blocks,
            currentProgram: currentProgram,
            recentLogs: recentLogs,
            progressionStates: fetchedProgressionStates,
            familyStates: familyStates
        )

        let resolution = resolveRollover(
            previousBlock: previous,
            newFocusAreas: focusAreas,
            exerciseHistory: exerciseHistory,
            cutModeActive: profile.cutMode.enabled
        )

        // TrainingStyle default was archetype-keyed. Map via programTemplateKey:
        //   power → freeWeights, control → bodyweight, endurance/others → hybrid.
        // MIGRATION: replaced TrainingStyle.default(for: archetype).
        let defaultStyle: TrainingStyle
        switch buildIdentity.programTemplateKey {
        case "power":   defaultStyle = .freeWeights
        case "control": defaultStyle = .bodyweight
        default:        defaultStyle = .hybrid
        }
        let style = profile.trainingStyleOverride ?? defaultStyle
        let feedback = profile.trainingFeedbackMode ?? TrainingFeedbackMode.default(for: experience)

        let preferences = (try? await ExercisePreferenceService.shared.fetchPreferences(userId: userId)) ?? []

        let input = ProgramGeneratorInput(
            userId: userId,
            scanId: scan?.id,
            analysisId: analysis?.id,
            buildIdentity: buildIdentity,
            trainingStyle: style,
            equipment: profile.equipment ?? [.bodyweight],
            targetFrequency: frequency,
            trainingDays: trainingDays,
            experience: experience,
            sessionLengthMinutes: profile.sessionLength?.minutes ?? defaultSessionMinutes(for: experience),
            focusAreas: focusAreas,
            cutModeActive: profile.cutMode.enabled,
            trainingFeedbackMode: feedback,
            progressionStates: progressionStates,
            previousBlock: previous,
            exerciseRotationsToApply: resolution.exercisesToRotate,
            weightKg: weight,
            heightCm: height,
            age: age,
            sex: sex,
            blockStartDate: Date(),
            exercisePreferences: preferences,
            calibration: .standardReady(knownExerciseKeys: Set(progressionStates.keys))
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

    static func exerciseHistory(
        previousBlock: ProgramBlock?,
        blocks: [ProgramBlock],
        currentProgram: TrainingProgram?,
        recentLogs: [WorkoutLog],
        progressionStates: [ProgressionState],
        familyStates: [ProgressionFamilyState] = []
    ) -> [String: ExerciseRefreshRule.ExerciseHistory] {
        let sortedBlocks = rolloverBlocks(
            blocks: blocks,
            previousBlock: previousBlock,
            currentProgram: currentProgram
        )
        guard !sortedBlocks.isEmpty else { return [:] }

        var exerciseKeysByProgramId: [String: Set<String>] = [:]
        for log in recentLogs {
            let keys = Set(log.exerciseEntries.compactMap(loggedExerciseKey))
            guard !keys.isEmpty else { continue }
            exerciseKeysByProgramId[log.programId, default: []].formUnion(keys)
        }
        if let currentProgram {
            exerciseKeysByProgramId[currentProgram.id, default: []].formUnion(
                prescribedExerciseKeys(in: currentProgram)
            )
        }

        let blockSets = sortedBlocks.map { block in
            (
                block: block,
                keys: exerciseKeysByProgramId[block.programId, default: []]
            )
        }
        guard let latest = blockSets.first, !latest.keys.isEmpty else { return [:] }

        let statesByKey = progressionStateMap(progressionStates)
        let familyStatesByFamily = Dictionary(uniqueKeysWithValues: familyStates.map { ($0.family, $0) })
        let freshStimulusCutoff = latest.block.startedAt

        var result: [String: ExerciseRefreshRule.ExerciseHistory] = [:]
        for key in latest.keys {
            var count = 0
            for blockSet in blockSets {
                if blockSet.keys.contains(key) {
                    count += 1
                } else {
                    break
                }
            }

            guard count > 0 else { continue }
            let state = statesByKey[key]
            let family = MovementCatalog.canonicalExercise(named: key)?.progressionFamily
            let hadTierUnlock = family
                .flatMap { familyStatesByFamily[$0] }
                .map { $0.updatedAt >= freshStimulusCutoff } ?? false
            let hadPlateauDeload = state.map {
                $0.blockType == .deload && $0.updatedAt >= freshStimulusCutoff
            } ?? false

            result[key] = ExerciseRefreshRule.ExerciseHistory(
                exerciseKey: key,
                consecutiveBlocksPrescribed: count,
                hadTierUnlock: hadTierUnlock,
                hadPlateauDeload: hadPlateauDeload
            )
        }
        return result
    }

    private static func rolloverBlocks(
        blocks: [ProgramBlock],
        previousBlock: ProgramBlock?,
        currentProgram: TrainingProgram?
    ) -> [ProgramBlock] {
        var sorted = blocks.sorted { lhs, rhs in lhs.blockNumber > rhs.blockNumber }
        guard let currentProgram else { return sorted }
        if sorted.contains(where: { $0.programId == currentProgram.id }) {
            return sorted
        }

        let virtualBlock = ProgramBlock(
            id: "active-\(currentProgram.id)",
            userId: currentProgram.userId,
            programId: currentProgram.id,
            blockNumber: previousBlock?.blockNumber ?? 1,
            startedAt: currentProgram.createdAt,
            scanId: currentProgram.scanId.isEmpty ? nil : currentProgram.scanId,
            accessoryBias: previousBlock?.accessoryBias ?? [:],
            cutModeActive: previousBlock?.cutModeActive ?? false,
            biasRefreshedFromPrevious: previousBlock?.biasRefreshedFromPrevious ?? false,
            exerciseRotationsThisBlock: previousBlock?.exerciseRotationsThisBlock ?? []
        )
        sorted.insert(virtualBlock, at: 0)
        return sorted
    }

    private static func prescribedExerciseKeys(in program: TrainingProgram) -> Set<String> {
        Set(program.days
            .compactMap(\.workout)
            .flatMap(\.mainExercises)
            .map { exerciseKey(name: $0.name) }
            .filter { !$0.isEmpty })
    }

    private static func loggedExerciseKey(_ entry: ExerciseLogEntry) -> String? {
        guard !entry.skipped else { return nil }
        guard entry.sets.contains(where: { !$0.isWarmup && $0.reps > 0 }) else { return nil }
        let key = exerciseKey(
            name: entry.exerciseName,
            movementId: entry.movementId,
            rankStandardMovementId: entry.rankStandardMovementId
        )
        return key.isEmpty ? nil : key
    }

    private static func progressionStateMap(_ states: [ProgressionState]) -> [String: ProgressionState] {
        var map: [String: ProgressionState] = [:]
        for state in states {
            map[MovementCatalog.normalized(state.exerciseKey)] = state
            map[MovementCatalog.normalized(state.displayName)] = state
        }
        return map
    }

    private static func exerciseKey(
        name: String,
        movementId: String? = nil,
        rankStandardMovementId: String? = nil
    ) -> String {
        if let resolved = MovementCatalog.resolvedTrainingMovement(
            name: name,
            movementId: movementId,
            rankStandardMovementId: rankStandardMovementId
        ) {
            let exact = resolved.exact.canonicalExerciseName ?? resolved.exact.displayName
            return MovementCatalog.normalized(exact)
        }
        if let definition = MovementCatalog.canonicalExercise(named: name) {
            return MovementCatalog.normalized(definition.canonicalExerciseName ?? definition.displayName)
        }
        return MovementCatalog.normalized(name)
    }

    @MainActor
    private static func activeProgram(userId: String) -> TrainingProgram? {
        if ProgramStore.shared.program == nil {
            _ = ProgramStore.shared.loadLocal(userId: userId)
        }
        guard ProgramStore.shared.program?.userId == userId else { return nil }
        return ProgramStore.shared.program
    }

    private static func defaultSessionMinutes(for experience: Experience) -> Int {
        switch experience {
        case .never, .tried: return 45
        case .used: return 60
        case .current: return 75
        }
    }
}
