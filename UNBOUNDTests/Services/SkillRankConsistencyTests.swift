import XCTest
@testable import UNBOUND

/// Locks the two rank paths to ONE source. Before the standards consolidation a
/// bodyweight skill (pull-up, push-up, dip, plank, l-sit, dead hang, hollow) was
/// ranked twice with different numbers: the skill tree (`computeTier`) and the
/// lift path (`computeLiftRank`, off the old repLadders/holdLadders). A user
/// could see one tier on the skill card and a different one from the reward/
/// badge path for the SAME set.
///
/// Now `computeLiftRank` routes bodyweight skills through `SkillStandards`, which
/// reads the node's generated tier criteria — the same thresholds `computeTier`
/// walks. These tests sweep values across both paths and assert they never
/// disagree. If they ever do, the single source has been forked again.
@MainActor
final class SkillRankConsistencyTests: XCTestCase {

    private let service = RankService.shared
    private let bodyweightKg = 70.0

    private func set(reps: Int = 0, durationSeconds: Int? = nil) -> SetLog {
        SetLog(id: UUID().uuidString, setNumber: 1, weightKg: nil, reps: reps,
               rpe: 8, isWarmup: false, durationSeconds: durationSeconds)
    }

    private func entry(_ name: String, node: String, _ sets: [SetLog]) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: "entry-\(node)", exerciseName: name, movementId: nil,
            rankStandardMovementId: node, plannedSets: sets.count, plannedReps: "—",
            sets: sets, skipped: false, notes: nil
        )
    }

    /// (display name, node id) for every rep movement ranked by SkillStandards.
    private let repMovements: [(name: String, node: String)] = [
        ("pullup", "pp.pullup"),
        ("pushup", "cal.pushup"),
        ("dip", "cal.5-dips")
    ]

    /// (display name, node id) for every hold movement ranked by SkillStandards.
    private let holdMovements: [(name: String, node: String)] = [
        ("plank", "cal.plank-30"),
        ("l-sit", "cal.l-sit-10"),
        ("dead hang", "pp.dead-hang"),
        ("hollow body hold", "cl.hollow-body-30")
    ]

    private func skillTier(nodeId: String, entry e: ExerciseLogEntry) -> SkillTier {
        guard let node = SkillGraph.shared.node(id: nodeId) else {
            XCTFail("missing skill node \(nodeId)")
            return .initiate
        }
        return service.computeTier(skill: node, history: [e], bodyweightKg: bodyweightKg)
    }

    func testRepMovementsAgreeAcrossBothPaths() {
        for (name, node) in repMovements {
            for reps in [1, 3, 5, 8, 12, 18, 25, 35, 50, 70] {
                let e = entry(name, node: node, [set(reps: reps)])
                let lift = service.computeLiftRank(entry: e, bodyweightKg: bodyweightKg)
                let tree = skillTier(nodeId: node, entry: e)
                XCTAssertEqual(lift, tree,
                    "\(name) @ \(reps) reps: lift path \(String(describing: lift)) != skill tree \(tree)")
            }
        }
    }

    func testHoldMovementsAgreeAcrossBothPaths() {
        for (name, node) in holdMovements {
            for seconds in [3, 10, 20, 30, 45, 60, 90, 120, 180] {
                let e = entry(name, node: node, [set(durationSeconds: seconds)])
                let lift = service.computeLiftRank(entry: e, bodyweightKg: bodyweightKg)
                let tree = skillTier(nodeId: node, entry: e)
                XCTAssertEqual(lift, tree,
                    "\(name) @ \(seconds)s: lift path \(String(describing: lift)) != skill tree \(tree)")
            }
        }
    }

    /// Legacy holds encoded seconds in the reps column (no durationSeconds). Both
    /// paths must still agree.
    func testLegacyRepsColumnHoldsAgree() {
        for (name, node) in holdMovements {
            for seconds in [10, 30, 60, 120] {
                let e = entry(name, node: node, [set(reps: seconds)])
                let lift = service.computeLiftRank(entry: e, bodyweightKg: bodyweightKg)
                let tree = skillTier(nodeId: node, entry: e)
                XCTAssertEqual(lift, tree,
                    "\(name) @ \(seconds)s (reps column): \(String(describing: lift)) != \(tree)")
            }
        }
    }
}
