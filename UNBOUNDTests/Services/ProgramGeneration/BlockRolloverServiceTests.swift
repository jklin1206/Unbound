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
}
