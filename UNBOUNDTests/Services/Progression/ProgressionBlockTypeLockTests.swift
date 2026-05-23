import XCTest
@testable import UNBOUND

final class ProgressionBlockTypeLockTests: XCTestCase {
    func testSeedDefaultsToAccumulation() {
        let state = ProgressionState.seed(
            userId: "u",
            exercise: "bench press",
            startingWeightKg: 60
        )
        XCTAssertEqual(state.blockType, .accumulation)
    }

    // If a caller explicitly passes a different block, it's honored. That's
    // intentional — we're only locking the DEFAULT, not removing the ability
    // for deload to be set explicitly by the DeloadPlanner.
    func testExplicitBlockPassedThrough() {
        let state = ProgressionState.seed(
            userId: "u",
            exercise: "squat",
            startingWeightKg: 100,
            block: .deload
        )
        XCTAssertEqual(state.blockType, .deload)
    }
}
