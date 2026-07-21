import XCTest
@testable import UNBOUND

final class DayTemplateTests: XCTestCase {
    func testRestDayFlag() {
        XCTAssertTrue(DayTemplate.rest.isRest)
        XCTAssertFalse(DayTemplate.push.isRest)
        XCTAssertFalse(DayTemplate.weakPoint.isRest)
    }

    func testMuscleGroupsPerTemplate() {
        XCTAssertTrue(DayTemplate.push.muscleGroups.contains(.chest))
        XCTAssertTrue(DayTemplate.push.muscleGroups.contains(.shoulders))
        XCTAssertTrue(DayTemplate.push.muscleGroups.contains(.triceps))
        XCTAssertTrue(DayTemplate.pull.muscleGroups.contains(.back))
        XCTAssertTrue(DayTemplate.pull.muscleGroups.contains(.lats))
        XCTAssertTrue(DayTemplate.pull.muscleGroups.contains(.biceps))
        // Legs/lower now carry fine-grained quads/hamstrings tags, not the
        // legacy coarse .legs group.
        XCTAssertTrue(DayTemplate.legs.muscleGroups.contains(.quads))
        XCTAssertTrue(DayTemplate.legs.muscleGroups.contains(.hamstrings))
        XCTAssertTrue(DayTemplate.legs.muscleGroups.contains(.glutes))
        XCTAssertFalse(DayTemplate.legs.muscleGroups.contains(.legs))
        XCTAssertTrue(DayTemplate.upper.muscleGroups.contains(.back))
        XCTAssertTrue(DayTemplate.upper.muscleGroups.contains(.chest))
        XCTAssertTrue(DayTemplate.upper.muscleGroups.contains(.biceps))
        XCTAssertTrue(DayTemplate.upper.muscleGroups.contains(.triceps))
        XCTAssertTrue(DayTemplate.lower.muscleGroups.contains(.quads))
        XCTAssertTrue(DayTemplate.lower.muscleGroups.contains(.hamstrings))
        XCTAssertFalse(DayTemplate.lower.muscleGroups.contains(.legs))
        XCTAssertTrue(DayTemplate.fullBody.muscleGroups.contains(.chest))
        XCTAssertTrue(DayTemplate.fullBody.muscleGroups.contains(.quads))
        XCTAssertTrue(DayTemplate.fullBody.muscleGroups.contains(.hamstrings))
        XCTAssertFalse(DayTemplate.fullBody.muscleGroups.contains(.legs))
        XCTAssertEqual(DayTemplate.skill.muscleGroups, [.core, .biceps, .triceps, .shoulders])
        XCTAssertEqual(DayTemplate.rest.muscleGroups, [])
        XCTAssertEqual(DayTemplate.weakPoint.muscleGroups, [])
    }

    func testAllCasesHaveDisplayLabel() {
        for t in DayTemplate.allCases {
            XCTAssertFalse(t.displayLabel.isEmpty)
        }
    }

    func testCodableRoundtrip() throws {
        let original: DayTemplate = .push
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DayTemplate.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

/// Locks the MuscleGroup fine-grained split: the catalog, day templates, and
/// skill graph must emit only the fine-grained cases going forward, while the
/// legacy coarse `.arms`/`.legs` cases stay decodable and modernize correctly
/// wherever persisted data can still carry them.
final class MuscleGroupMigrationTests: XCTestCase {
    func testCatalogEmitsNoLegacyMuscleTags() {
        for exercise in ExerciseCatalog.allExercises {
            XCTAssertFalse(exercise.muscleGroups.contains(.arms), "\(exercise.name) still tags .arms")
            XCTAssertFalse(exercise.muscleGroups.contains(.legs), "\(exercise.name) still tags .legs")
        }

        for definition in MovementCatalog.definitions where !definition.muscleGroups.isEmpty {
            XCTAssertFalse(definition.muscleGroups.contains(.arms), "\(definition.id) still tags .arms")
            XCTAssertFalse(definition.muscleGroups.contains(.legs), "\(definition.id) still tags .legs")
        }
    }

    func testDayTemplatesEmitNoLegacyMuscleTags() {
        for template in DayTemplate.allCases {
            XCTAssertFalse(template.muscleGroups.contains(.arms), "\(template) still tags .arms")
            XCTAssertFalse(template.muscleGroups.contains(.legs), "\(template) still tags .legs")
        }
    }

    func testLegacyMuscleGroupDecoding() throws {
        let json = #"["arms","legs","biceps"]"#
        let decoded = try JSONDecoder().decode([MuscleGroup].self, from: Data(json.utf8))
        XCTAssertEqual(decoded, [.arms, .legs, .biceps])
        XCTAssertEqual(MuscleGroup.modernized(decoded), [.biceps, .triceps, .quads, .hamstrings])
    }

    func testWeakPointBiaserSpreadsLegacyFocusOverFineGrainedTags() {
        let focus = [FocusArea(muscleGroup: .arms, priority: 1, rationale: "", suggestedFocus: "")]
        let bias = WeakPointBiaser.bias(from: focus)
        XCTAssertEqual(bias[.biceps], 2)
        XCTAssertEqual(bias[.triceps], 2)

        struct Ex: Equatable { let name: String; let groups: [MuscleGroup] }
        let tricepCandidate = Ex(name: "tricep-pushdown", groups: [.triceps])
        let unrelated = Ex(name: "calf-raise", groups: [.calves])

        // pickBiased must prefer the triceps-tagged candidate over an unrelated one.
        let picked = WeakPointBiaser.pickBiased(
            candidates: [unrelated, tricepCandidate],
            biasedGroups: bias,
            biasedGroupsFor: { $0.groups }
        )
        XCTAssertEqual(picked, tricepCandidate)

        // addAccessories only keeps candidates that score > 0 against the bias.
        let added = WeakPointBiaser.addAccessories(
            to: [Ex](),
            from: [tricepCandidate, unrelated],
            biasedGroups: bias,
            maxAccessories: 2,
            targetGroupsFor: { $0.groups }
        )
        XCTAssertEqual(added, [tricepCandidate])
    }

    func testSkillGraphNodesEmitNoLegacyMuscleTags() {
        for node in SkillGraph.shared.nodes {
            XCTAssertFalse(node.primaryMuscles.contains(.arms), "\(node.id) primaryMuscles still tags .arms")
            XCTAssertFalse(node.primaryMuscles.contains(.legs), "\(node.id) primaryMuscles still tags .legs")
            XCTAssertFalse(node.secondaryMuscles.contains(.arms), "\(node.id) secondaryMuscles still tags .arms")
            XCTAssertFalse(node.secondaryMuscles.contains(.legs), "\(node.id) secondaryMuscles still tags .legs")
        }
    }
}
