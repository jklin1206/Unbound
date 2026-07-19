import XCTest
@testable import UNBOUND

@MainActor
final class AutoDeloadTests: XCTestCase {

    private func state(
        block: BlockType = .accumulation,
        name: String = "back squat",
        cooldown: Int? = nil
    ) -> ProgressionState {
        var s = ProgressionState.seed(userId: "u", exercise: name, startingWeightKg: 100, block: block)
        s.deloadCooldownRemaining = cooldown
        return s
    }

    private func keys(_ names: String...) -> Set<String> {
        Set(names.map { $0.lowercased() })
    }

    /// (a) A systemic plateau signal auto-deloads ONLY the plateaued lifts; a
    /// progressing lift keeps its own targets and is never dragged in.
    func testSystemicPlateauDeloadsOnlyPlateauedLifts() throws {
        let squat = state(name: "back squat")
        let bench = state(name: "bench press")
        let ohp = state(name: "overhead press") // progressing — not in the plateau set
        let deloaded = try XCTUnwrap(
            AutoDeloadService.plan(
                states: [squat, bench, ohp],
                plateauedKeys: keys("back squat", "bench press")
            ),
            "Two fresh plateaus meet the systemic threshold and must deload"
        )
        XCTAssertEqual(deloaded.count, 2, "Only the two plateaued lifts get deloaded")
        XCTAssertTrue(deloaded.allSatisfy { $0.blockType == .deload })
        XCTAssertFalse(
            deloaded.contains { $0.exerciseKey == "overhead press" },
            "A progressing lift must not be dragged into the deload"
        )
        XCTAssertTrue(
            deloaded.allSatisfy { $0.deloadSessionsCompleted == 0 },
            "Entering a deload seeds the bounded exit counter"
        )
    }

    /// A single plateaued lift is below the systemic threshold — no deload.
    func testLonePlateauDoesNotDeload() {
        let plan = AutoDeloadService.plan(
            states: [state(name: "back squat"), state(name: "bench press")],
            plateauedKeys: keys("back squat")
        )
        XCTAssertNil(plan, "A single plateaued lift is below the systemic threshold")
    }

    /// The threshold is a named constant, not a magic number.
    func testSystemicThresholdIsHonored() {
        var names: [String] = []
        var plateaued: Set<String> = []
        for i in 0..<DeloadPolicy.systemicPlateauThreshold {
            names.append("lift-\(i)")
            plateaued.insert("lift-\(i)")
        }
        let states = names.map { state(name: $0) }
        XCTAssertNotNil(
            AutoDeloadService.plan(states: states, plateauedKeys: plateaued),
            "Exactly the threshold count of plateaus must trigger a deload"
        )

        // One below the threshold must not fire.
        let belowNames = Array(names.dropLast())
        let belowStates = belowNames.map { state(name: $0) }
        XCTAssertNil(
            AutoDeloadService.plan(states: belowStates, plateauedKeys: Set(belowNames)),
            "One below the threshold must not trigger a deload"
        )
    }

    /// (d) Self-healing anti-thrash: a lift inside its post-deload cooldown is
    /// not re-deloaded even while it re-registers as plateaued; once the cooldown
    /// lapses, evaluation resumes and the deload can fire again.
    func testCooldownBlocksReDeloadThenResumes() {
        let squatCooling = state(name: "back squat", cooldown: DeloadPolicy.postDeloadCooldownSessions)
        let benchCooling = state(name: "bench press", cooldown: DeloadPolicy.postDeloadCooldownSessions)
        XCTAssertNil(
            AutoDeloadService.plan(
                states: [squatCooling, benchCooling],
                plateauedKeys: keys("back squat", "bench press")
            ),
            "Cooldown must block an immediate re-deload after an exit"
        )

        let squatReady = state(name: "back squat", cooldown: 0)
        let benchReady = state(name: "bench press", cooldown: 0)
        XCTAssertNotNil(
            AutoDeloadService.plan(
                states: [squatReady, benchReady],
                plateauedKeys: keys("back squat", "bench press")
            ),
            "Once the cooldown lapses, evaluation resumes and the deload fires"
        )
    }

    /// A lift already mid-deload is excluded from a new deload (it exits on its
    /// own after the bounded session count) — only fresh plateaus deload.
    func testAlreadyDeloadingLiftIsExcludedFromNewDeload() {
        let deloading = state(block: .deload, name: "back squat")
        let plan = AutoDeloadService.plan(
            states: [deloading, state(name: "bench press"), state(name: "overhead press")],
            plateauedKeys: keys("back squat", "bench press", "overhead press")
        )
        let deloaded = plan ?? []
        XCTAssertEqual(deloaded.count, 2, "Only the two fresh plateaus deload")
        XCTAssertFalse(
            deloaded.contains { $0.exerciseKey == "back squat" },
            "A lift already deloading is not re-deloaded"
        )
    }

    /// Applying a deload persists each planned row under its own document id.
    /// The planner preserves the stable `userId:exerciseKey` id, so writing the
    /// plan is an idempotent upsert — a full re-apply after a partial write
    /// failure (the manual Deload sheet's retry) overwrites the same rows in
    /// place rather than forking new ones.
    func testPlanDeloadPreservesRowIdForIdempotentReapply() {
        let states = [state(name: "back squat"), state(name: "bench press")]
        let planned = DeloadPlanner.shared.planDeload(for: states)
        XCTAssertEqual(planned.map(\.id), states.map(\.id))
        XCTAssertTrue(planned.allSatisfy { $0.blockType == .deload })
        XCTAssertTrue(planned.allSatisfy { $0.deloadSessionsCompleted == 0 })
    }
}
