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
final class SkillStandardConsistencyTests: XCTestCase {

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
        ("dip", "cal.5-dips"),
        ("split squat", "ld.split-squat"),
        ("bulgarian split squat", "ld.bulgarian-split-squat"),
        ("step up", "ld.step-up"),
        ("bodyweight leg extension", "ld.leg-extensions"),
        ("pistol squat", "ld.pistol-squat"),
        ("shrimp squat", "ld.shrimp-squat"),
        ("nordic curl", "ld.nordic-curl")
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

    private func criterionExerciseNames(for nodeId: String) -> Set<String> {
        guard let node = SkillGraph.shared.node(id: nodeId) else {
            XCTFail("missing skill node \(nodeId)")
            return []
        }
        return Set(node.tierCriteria.values.compactMap { criterion in
            switch criterion {
            case .reps(_, let exerciseName),
                 .exerciseSeconds(_, let exerciseName),
                 .exerciseWeightKg(_, let exerciseName),
                 .exerciseBodyweightRatio(_, let exerciseName):
                return exerciseName
            case .variant(let name):
                return name
            case .compound, .seconds, .weightKg, .bodyweightRatio:
                return nil
            }
        })
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

    func testDefyingGravityLegGoalsExistInSkillTree() {
        let expectedGoalIds = [
            "ld.step-up",
            "ld.split-squat",
            "ld.bulgarian-split-squat",
            "ld.pistol-squat",
            "ld.weighted-pistol",
            "ld.shrimp-squat",
            "ld.nordic-curl"
        ]

        for id in expectedGoalIds {
            let node = SkillGraph.shared.node(id: id)
            XCTAssertNotNil(node, "\(id) should be a live skill-tree goal")
            XCTAssertFalse(node?.tierCriteria.isEmpty ?? true, "\(id) should have rank criteria")
            XCTAssertNotNil(SkillTrainingPlanLibrary.plan(for: id), "\(id) should have a training plan")
        }

        XCTAssertEqual(
            SkillGraph.shared.node(id: "ld.pistol-squat")?.prereqs,
            [PrerequisiteGroup(["ld.deep-squat", "ld.bulgarian-split-squat"])]
        )
        XCTAssertEqual(
            SkillGraph.shared.node(id: "ld.shrimp-squat")?.prereqs,
            [PrerequisiteGroup("ld.pistol-squat")]
        )
    }

    func testDefyingGravityLegGoalCriteriaUseProgressionVariants() {
        XCTAssertTrue(
            criterionExerciseNames(for: "ld.pistol-squat").isSuperset(of: Set([
                "partial pistol squat",
                "assisted pistol squat",
                "pistol squat"
            ]))
        )
        XCTAssertTrue(
            criterionExerciseNames(for: "ld.shrimp-squat").isSuperset(of: Set([
                "assisted shrimp squat",
                "beginner shrimp squat",
                "intermediate shrimp squat",
                "shrimp squat",
                "two-hand shrimp squat",
                "elevated two-hand shrimp squat"
            ]))
        )
        XCTAssertTrue(
            criterionExerciseNames(for: "ld.nordic-curl").isSuperset(of: Set([
                "nordic curl negative",
                "nordic curl",
                "nordic curl arms overhead",
                "tuck one-leg nordic curl",
                "one-leg nordic curl"
            ]))
        )
    }

    func testDefyingGravityRegressionLogsAdvanceOnlyTheirGoalRungs() {
        XCTAssertEqual(
            skillTier(nodeId: "ld.pistol-squat", entry: entry("partial pistol squat", node: "ld.pistol-squat", [set(reps: 8)])),
            .novice
        )
        XCTAssertEqual(
            skillTier(nodeId: "ld.pistol-squat", entry: entry("assisted pistol squat", node: "ld.pistol-squat", [set(reps: 5)])),
            .apprentice
        )
        XCTAssertEqual(
            skillTier(nodeId: "ld.pistol-squat", entry: entry("pistol squat", node: "ld.pistol-squat", [set(reps: 1)])),
            .forged
        )
        XCTAssertEqual(
            skillTier(nodeId: "ld.shrimp-squat", entry: entry("beginner shrimp squat", node: "ld.shrimp-squat", [set(reps: 3)])),
            .novice
        )
        XCTAssertEqual(
            skillTier(nodeId: "ld.shrimp-squat", entry: entry("intermediate shrimp squat", node: "ld.shrimp-squat", [set(reps: 3)])),
            .apprentice
        )
        XCTAssertEqual(
            skillTier(nodeId: "ld.shrimp-squat", entry: entry("two-hand shrimp squat", node: "ld.shrimp-squat", [set(reps: 3)])),
            .ascendant
        )
        XCTAssertEqual(
            skillTier(nodeId: "ld.nordic-curl", entry: entry("nordic curl negative", node: "ld.nordic-curl", [set(reps: 5)])),
            .apprentice
        )
        XCTAssertEqual(
            skillTier(nodeId: "ld.nordic-curl", entry: entry("nordic curl", node: "ld.nordic-curl", [set(reps: 1)])),
            .forged
        )
        XCTAssertEqual(
            skillTier(nodeId: "ld.nordic-curl", entry: entry("one-leg nordic curl", node: "ld.nordic-curl", [set(reps: 1)])),
            .unbound
        )
    }

    func testDefyingGravityLegGoalPlansNameTheAuthoredRungs() {
        func names(for skillId: String) -> Set<String> {
            guard let plan = SkillTrainingPlanLibrary.plan(for: skillId) else {
                XCTFail("missing plan for \(skillId)")
                return []
            }
            return Set(
                plan.regressions.map(\.name)
                + plan.mainSets.map(\.exerciseName)
                + plan.accessories.map(\.name)
            )
        }

        XCTAssertTrue(names(for: "ld.pistol-squat").isSuperset(of: Set([
            "Partial Pistol Squat",
            "Assisted Pistol Squat",
            "Pistol Squat",
            "Cossack Squat"
        ])))
        XCTAssertTrue(names(for: "ld.shrimp-squat").isSuperset(of: Set([
            "Assisted Shrimp Squat",
            "Beginner Shrimp Squat",
            "Intermediate Shrimp Squat",
            "Shrimp Squat",
            "Two-Hand Shrimp Squat",
            "Elevated Two-Hand Shrimp Squat"
        ])))
        XCTAssertTrue(names(for: "ld.nordic-curl").isSuperset(of: Set([
            "Nordic Curl Negative",
            "Nordic Curl",
            "Nordic Curl Arms Overhead",
            "Tuck One-Leg Nordic Curl",
            "One-Leg Nordic Curl"
        ])))
    }
}
