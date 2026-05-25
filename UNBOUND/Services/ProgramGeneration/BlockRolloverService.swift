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
                    return "This scan can bias the next block, but it will not rewrite today's workout or the current split."
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
            weaknesses: delta.laggingAreas
        )
    }

    private static func focusAreas(from delta: ScanDeltaReport?) -> [FocusArea] {
        guard let delta else { return [] }
        let rawAreas = delta.laggingAreas.isEmpty ? [delta.recommendedFocus] : delta.laggingAreas
        var seen = Set<MuscleGroup>()
        return rawAreas.compactMap(muscleGroup(named:))
            .prefix(2)
            .enumerated()
            .compactMap { index, muscleGroup in
                guard seen.insert(muscleGroup).inserted else { return nil }
                return FocusArea(
                    muscleGroup: muscleGroup,
                    priority: index + 1,
                    rationale: "Monthly scan checkpoint",
                    suggestedFocus: delta.recommendedFocus
                )
            }
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
                    title: "Scan checkpoint included",
                    detail: improvement.map { "\($0) is trending up; the next block can use the latest checkpoint." }
                        ?? "The next block can use the latest scan checkpoint without changing today's workout."
                )
            )
        } else {
            lines.append(
                ProgramBlockProposal.Line(
                    kind: .rescan,
                    title: "Rescan optional",
                    detail: "You can build the next block from training history now, or scan first for fresher bias."
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

    private static func muscleGroup(named raw: String) -> MuscleGroup? {
        let normalized = raw
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return MuscleGroup.allCases.first { group in
            group.rawValue == normalized || group.displayName.lowercased() == normalized
        }
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

        var progressionStates: [String: ProgressionState] = [:]
        for state in await ProgressionStateStore.shared.fetchAll(userId: userId) {
            progressionStates[MovementCatalog.normalized(state.exerciseKey)] = state
        }
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
            focusAreas: focusAreas,
            cutModeActive: profile.cutMode.enabled,
            trainingFeedbackMode: feedback,
            progressionStates: progressionStates,
            previousBlock: previous,
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
}
