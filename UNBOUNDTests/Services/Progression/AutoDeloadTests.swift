import XCTest
@testable import UNBOUND

@MainActor
final class AutoDeloadTests: XCTestCase {

    private func state(week: Int, block: BlockType = .accumulation, name: String = "back squat") -> ProgressionState {
        ProgressionState.seed(userId: "u", exercise: name, startingWeightKg: 100, block: block, weekInBlock: week)
    }

    /// Kickoff proof: 2 plateaus → next resolved day is a deload (no Coach tap).
    func testTwoPlateausAutoDeloads() {
        let states = [state(week: 2, name: "back squat"), state(week: 2, name: "bench press")]
        let plan = AutoDeloadService.plan(states: states, plateauCount: 2)
        XCTAssertNotNil(plan, "2 plateaus must auto-trigger a deload")
        XCTAssertTrue(plan!.allSatisfy { $0.blockType == .deload })
        XCTAssertTrue(plan!.allSatisfy { $0.targetRPE == BlockType.deload.targetRPE })
    }

    func testOnePlateauDoesNotDeload() {
        let plan = AutoDeloadService.plan(states: [state(week: 2)], plateauCount: 1)
        XCTAssertNil(plan, "A single plateau is not enough to deload")
    }

    /// Anti-thrash: already in a deload block → never re-deload.
    func testAlreadyDeloadedDoesNotRetrigger() {
        let states = [state(week: 1, block: .deload), state(week: 2)]
        XCTAssertNil(AutoDeloadService.plan(states: states, plateauCount: 5),
                     "Must not re-deload an athlete already deloading")
    }

    /// Week-4 stagnation triggers a deload even without explicit plateaus.
    func testWeekFourTriggersDeload() {
        let plan = AutoDeloadService.plan(states: [state(week: 4)], plateauCount: 0)
        XCTAssertNotNil(plan, "Reaching week 4 in-block warrants a deload")
    }
}
