import XCTest
@testable import UNBOUND

final class BlockRolloverServiceTests: XCTestCase {

    func testCarriesBiasForwardAndRotatesStaleExercises() {
        let prev = ProgramBlock(
            id: "b-1", userId: "u-1", programId: "p-1",
            blockNumber: 1,
            startedAt: Date(), scanId: nil,
            accessoryBias: [.shoulders: 2, .back: 1],
            cutModeActive: false,
            biasRefreshedFromPrevious: false,
            exerciseRotationsThisBlock: []
        )
        let newFocus = [
            FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "", suggestedFocus: ""),
            FocusArea(muscleGroup: .back, priority: 2, rationale: "", suggestedFocus: "")
        ]
        let history: [String: ExerciseRefreshRule.ExerciseHistory] = [
            "bench press": .init(
                exerciseKey: "bench press",
                consecutiveBlocksPrescribed: 3,
                hadTierUnlock: false,
                hadPlateauDeload: false
            ),
            "squat": .init(
                exerciseKey: "squat",
                consecutiveBlocksPrescribed: 1,
                hadTierUnlock: false,
                hadPlateauDeload: false
            )
        ]
        let resolution = BlockRolloverService.resolveRollover(
            previousBlock: prev,
            newFocusAreas: newFocus,
            exerciseHistory: history,
            cutModeActive: false
        )
        XCTAssertTrue(resolution.accessoryBiasResult.carriedForward)
        XCTAssertTrue(resolution.exercisesToRotate.contains("bench press"))
        XCTAssertFalse(resolution.exercisesToRotate.contains("squat"))
    }

    func testRefreshesBiasWhenPrioritiesChanged() {
        let prev = ProgramBlock(
            id: "b-1", userId: "u-1", programId: "p-1",
            blockNumber: 1,
            startedAt: Date(), scanId: nil,
            accessoryBias: [.shoulders: 2, .back: 1],
            cutModeActive: false,
            biasRefreshedFromPrevious: false,
            exerciseRotationsThisBlock: []
        )
        let newFocus = [
            FocusArea(muscleGroup: .chest, priority: 1, rationale: "", suggestedFocus: ""),
            FocusArea(muscleGroup: .arms, priority: 2, rationale: "", suggestedFocus: "")
        ]
        let resolution = BlockRolloverService.resolveRollover(
            previousBlock: prev,
            newFocusAreas: newFocus,
            exerciseHistory: [:],
            cutModeActive: false
        )
        XCTAssertFalse(resolution.accessoryBiasResult.carriedForward)
        XCTAssertEqual(resolution.accessoryBiasResult.bias[.chest], 2)
    }

    func testNoPreviousBlock_usesNewScan() {
        let newFocus = [
            FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "", suggestedFocus: "")
        ]
        let resolution = BlockRolloverService.resolveRollover(
            previousBlock: nil,
            newFocusAreas: newFocus,
            exerciseHistory: [:],
            cutModeActive: false
        )
        XCTAssertFalse(resolution.accessoryBiasResult.carriedForward)
        XCTAssertEqual(resolution.accessoryBiasResult.bias[.shoulders], 2)
    }

    func testNoRotationsWhenHistoryEmpty() {
        let resolution = BlockRolloverService.resolveRollover(
            previousBlock: nil,
            newFocusAreas: [],
            exerciseHistory: [:],
            cutModeActive: false
        )
        XCTAssertTrue(resolution.exercisesToRotate.isEmpty)
    }

    func testMultipleExercisesPastThresholdAllRotate() {
        let history: [String: ExerciseRefreshRule.ExerciseHistory] = [
            "bench press": .init(
                exerciseKey: "bench press",
                consecutiveBlocksPrescribed: 4,
                hadTierUnlock: false,
                hadPlateauDeload: false
            ),
            "barbell row": .init(
                exerciseKey: "barbell row",
                consecutiveBlocksPrescribed: 3,
                hadTierUnlock: false,
                hadPlateauDeload: false
            ),
            "face pull": .init(
                exerciseKey: "face pull",
                consecutiveBlocksPrescribed: 5,
                hadTierUnlock: true,  // tier unlock prevents rotation
                hadPlateauDeload: false
            )
        ]
        let resolution = BlockRolloverService.resolveRollover(
            previousBlock: nil,
            newFocusAreas: [],
            exerciseHistory: history,
            cutModeActive: false
        )
        XCTAssertTrue(resolution.exercisesToRotate.contains("bench press"))
        XCTAssertTrue(resolution.exercisesToRotate.contains("barbell row"))
        XCTAssertFalse(resolution.exercisesToRotate.contains("face pull"))
    }

    func testBlockProposalKeepsScanRecapOutOfHiddenBodyBias() {
        let delta = makeDelta(
            improvements: ["shoulders"],
            laggingAreas: ["chest", "arms"],
            recommendedFocus: "Add more pressing accessories"
        )

        let proposal = BlockRolloverService.proposal(
            currentBlockNumber: 2,
            previousBlock: nil,
            latestDeltaReport: delta
        )

        XCTAssertEqual(proposal.nextBlockNumber, 3)
        XCTAssertFalse(proposal.shouldPromptRescan)
        XCTAssertEqual(proposal.midBlockPatchPolicy, .nextBlockOnly)
        XCTAssertEqual(
            proposal.midBlockPatchPolicy.detail,
            "This checkpoint can inform the next-block review, but it will not rewrite today's workout or body-grade the athlete."
        )
        XCTAssertTrue(proposal.focusAreas.isEmpty)
        XCTAssertTrue(proposal.lines.contains { $0.kind == .scan })
        XCTAssertFalse(proposal.lines.contains { $0.kind == .focus })

        let analysis = BlockRolloverService.analysis(from: proposal, userId: "u-1")
        XCTAssertNil(analysis)
    }

    func testBlockProposalPromptsOptionalRescanWhenNoDeltaExists() {
        let proposal = BlockRolloverService.proposal(
            currentBlockNumber: 1,
            previousBlock: nil,
            latestDeltaReport: nil
        )

        XCTAssertTrue(proposal.shouldPromptRescan)
        XCTAssertTrue(proposal.focusAreas.isEmpty)
        XCTAssertNil(BlockRolloverService.analysis(from: proposal, userId: "u-1"))
        XCTAssertEqual(proposal.lines.first?.kind, .rescan)
    }

    func testExerciseHistoryCountsCurrentPrescriptionAndLoggedPriorBlocks() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let blocks = [
            makeBlock(number: 3, programId: "program-1", startedAt: startedAt),
            makeBlock(number: 2, programId: "program-2", startedAt: startedAt.addingTimeInterval(-14 * 86_400)),
            makeBlock(number: 1, programId: "program-3", startedAt: startedAt.addingTimeInterval(-28 * 86_400))
        ]
        let currentProgram = ProgramTestFactory.makeProgram(
            days: [
                ProgramTestFactory.makeDay(dayNumber: 1, label: "Barbell Bench Press", role: .push, muscleGroups: [.chest]),
                ProgramTestFactory.makeDay(dayNumber: 2, label: "Lat Pulldown (Bar)", role: .pull, muscleGroups: [.back, .lats])
            ],
            createdAt: startedAt,
            withArc: true
        )
        let logs = [
            makeLog(programId: "program-2", exerciseNames: ["Barbell Bench Press", "Back Squat"], at: startedAt.addingTimeInterval(-7 * 86_400)),
            makeLog(programId: "program-3", exerciseNames: ["Bench Press"], at: startedAt.addingTimeInterval(-21 * 86_400))
        ]

        let history = BlockRolloverService.exerciseHistory(
            previousBlock: blocks[0],
            blocks: blocks,
            currentProgram: currentProgram,
            recentLogs: logs,
            progressionStates: [],
            familyStates: []
        )

        XCTAssertEqual(history["bench press"]?.consecutiveBlocksPrescribed, 3)
        XCTAssertEqual(history["lat pulldown"]?.consecutiveBlocksPrescribed, 1)
        XCTAssertNil(history["back squat"])
    }

    func testExerciseHistoryMarksFreshPlateauDeloadSignal() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let block = makeBlock(number: 3, programId: "program-1", startedAt: startedAt)
        let currentProgram = ProgramTestFactory.makeProgram(
            days: [
                ProgramTestFactory.makeDay(dayNumber: 1, label: "Barbell Bench Press", role: .push, muscleGroups: [.chest])
            ],
            createdAt: startedAt,
            withArc: true
        )
        var state = ProgressionState.seed(
            userId: "u-1",
            exercise: "bench press",
            startingWeightKg: 80,
            block: .deload
        )
        state.updatedAt = startedAt.addingTimeInterval(60)

        let history = BlockRolloverService.exerciseHistory(
            previousBlock: block,
            blocks: [block],
            currentProgram: currentProgram,
            recentLogs: [],
            progressionStates: [state],
            familyStates: []
        )

        XCTAssertEqual(history["bench press"]?.consecutiveBlocksPrescribed, 1)
        XCTAssertEqual(history["bench press"]?.hadPlateauDeload, true)
    }

    private func makeDelta(
        improvements: [String],
        laggingAreas: [String],
        recommendedFocus: String
    ) -> ScanDeltaReport {
        ScanDeltaReport(
            id: "delta-1",
            userId: "u-1",
            baselineScanId: "scan-before",
            comparisonScanId: "scan-after",
            createdAt: Date(timeIntervalSince1970: 100),
            shoulders: BodyPartDelta(before: 4, after: 6),
            chest: BodyPartDelta(before: 4, after: 5),
            arms: BodyPartDelta(before: 3, after: 4),
            core: BodyPartDelta(before: 5, after: 5),
            legs: BodyPartDelta(before: 5, after: 5),
            overall: BodyPartDelta(before: 4, after: 5),
            narrative: "Visible progress with a clear next focus.",
            improvements: improvements,
            laggingAreas: laggingAreas,
            recommendedFocus: recommendedFocus
        )
    }

    private func makeBlock(number: Int, programId: String, startedAt: Date) -> ProgramBlock {
        ProgramBlock(
            id: "block-\(number)",
            userId: "u-1",
            programId: programId,
            blockNumber: number,
            startedAt: startedAt,
            scanId: nil,
            accessoryBias: [:],
            cutModeActive: false,
            biasRefreshedFromPrevious: false,
            exerciseRotationsThisBlock: []
        )
    }

    private func makeLog(
        programId: String,
        exerciseNames: [String],
        at: Date
    ) -> WorkoutLog {
        WorkoutLog(
            id: "log-\(programId)-\(Int(at.timeIntervalSince1970))",
            userId: "u-1",
            programId: programId,
            dayNumber: 1,
            plannedWorkoutName: "Logged",
            startedAt: at,
            completedAt: at.addingTimeInterval(45 * 60),
            exerciseEntries: exerciseNames.enumerated().map { index, name in
                ExerciseLogEntry(
                    id: "entry-\(programId)-\(index)",
                    exerciseName: name,
                    plannedSets: 3,
                    plannedReps: "8-10",
                    sets: [
                        SetLog(
                            id: "set-\(programId)-\(index)",
                            setNumber: 1,
                            weightKg: 60,
                            reps: 8,
                            rpe: 7,
                            isWarmup: false
                        )
                    ],
                    skipped: false,
                    notes: nil
                )
            },
            overallNotes: nil,
            overallRPE: nil,
            durationMinutes: 45
        )
    }
}
