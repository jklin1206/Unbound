import XCTest
@testable import UNBOUND

final class AccessoryBiasRefreshRuleTests: XCTestCase {

    // MARK: No previous block

    func testNoPreviousBlock_refreshesFromScan() {
        let result = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: [
                FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "", suggestedFocus: "")
            ],
            previousBlock: nil
        )
        XCTAssertFalse(result.carriedForward)
        XCTAssertEqual(result.bias[.shoulders], 2)
    }

    func testNoPreviousBlock_emptyScan_yieldsEmptyBias() {
        let result = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: [],
            previousBlock: nil
        )
        XCTAssertFalse(result.carriedForward)
        XCTAssertTrue(result.bias.isEmpty)
    }

    // MARK: Top-2 unchanged

    func testSameTopTwoPriorities_carriesForward() {
        let prev = makeBlock(bias: [.shoulders: 2, .back: 1])
        let result = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: [
                FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "", suggestedFocus: ""),
                FocusArea(muscleGroup: .back, priority: 2, rationale: "", suggestedFocus: "")
            ],
            previousBlock: prev
        )
        XCTAssertTrue(result.carriedForward)
        XCTAssertEqual(result.bias, prev.accessoryBias)
    }

    func testSameTopTwoEvenIfOrderDiffers_carriesForward() {
        // Priority in new scan is [shoulders p1, back p2]; previous bias was
        // {.shoulders: 2, .back: 1}. The top-2 muscle groups are the same
        // regardless of in-dictionary ordering → should carry forward.
        let prev = makeBlock(bias: [.back: 1, .shoulders: 2])
        let result = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: [
                FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "", suggestedFocus: ""),
                FocusArea(muscleGroup: .back, priority: 2, rationale: "", suggestedFocus: "")
            ],
            previousBlock: prev
        )
        XCTAssertTrue(result.carriedForward)
    }

    // MARK: Top-2 changed

    func testDifferentTopPriority_refreshes() {
        let prev = makeBlock(bias: [.shoulders: 2, .back: 1])
        let result = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: [
                FocusArea(muscleGroup: .chest, priority: 1, rationale: "", suggestedFocus: ""),
                FocusArea(muscleGroup: .arms, priority: 2, rationale: "", suggestedFocus: "")
            ],
            previousBlock: prev
        )
        XCTAssertFalse(result.carriedForward)
        XCTAssertEqual(result.bias[.chest], 2)
        XCTAssertEqual(result.bias[.arms], 1)
        XCTAssertNil(result.bias[.shoulders])
    }

    func testPriorityRankSwapped_refreshes() {
        // Previous: shoulders=2, back=1. New: back p1, shoulders p2.
        // Even though the SAME groups are involved, their priority rank
        // changed — the top-1 is now back, not shoulders. Refresh.
        let prev = makeBlock(bias: [.shoulders: 2, .back: 1])
        let result = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: [
                FocusArea(muscleGroup: .back, priority: 1, rationale: "", suggestedFocus: ""),
                FocusArea(muscleGroup: .shoulders, priority: 2, rationale: "", suggestedFocus: "")
            ],
            previousBlock: prev
        )
        XCTAssertFalse(result.carriedForward)
        XCTAssertEqual(result.bias[.back], 2)
        XCTAssertEqual(result.bias[.shoulders], 1)
    }

    // MARK: Edge cases

    func testPreviousBlockHadBiasButNewScanIsEmpty_refreshesToEmpty() {
        let prev = makeBlock(bias: [.shoulders: 2, .back: 1])
        let result = AccessoryBiasRefreshRule.resolve(
            newFocusAreas: [],
            previousBlock: prev
        )
        XCTAssertFalse(result.carriedForward)
        XCTAssertTrue(result.bias.isEmpty)
    }

    // MARK: Helper

    private func makeBlock(bias: [MuscleGroup: Int]) -> ProgramBlock {
        ProgramBlock(
            id: "b",
            userId: "u",
            programId: "p",
            blockNumber: 1,
            startedAt: Date(),
            scanId: nil,
            accessoryBias: bias,
            cutModeActive: false,
            biasRefreshedFromPrevious: false,
            exerciseRotationsThisBlock: []
        )
    }
}
