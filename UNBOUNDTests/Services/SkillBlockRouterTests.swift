import XCTest
@testable import UNBOUND

final class SkillBlockRouterTests: XCTestCase {
    func testPrimerLandsBeforeMainWork() {
        let draft = makeDraft(blocks: [
            block(kind: .strength, title: "Main Lift"),
            block(kind: .routine, title: "Cooldown")
        ])

        let updated = SkillBlockRouter.insert(
            skillID: "strict_pull_up",
            title: "Strict Pull-Up",
            kind: .primer,
            into: draft
        )

        XCTAssertEqual(updated.blocks.first?.kind, .skill)
        XCTAssertEqual(updated.blocks.first?.skillId, "strict_pull_up")
    }

    func testMultipleSkillKindsKeepExpectedOrder() {
        var draft = makeDraft(blocks: [
            block(kind: .routine, title: "Warmup"),
            block(kind: .strength, title: "Main Lift"),
            block(kind: .custom, title: "Accessories")
        ])

        draft = SkillBlockRouter.insert(skillID: "l_sit", title: "L-Sit", kind: .mobility, into: draft)
        draft = SkillBlockRouter.insert(skillID: "handstand", title: "Handstand", kind: .main, into: draft)
        draft = SkillBlockRouter.insert(skillID: "strict_pull_up", title: "Strict Pull-Up", kind: .accessory, into: draft)

        XCTAssertEqual(draft.blocks.map(\.skillId), [nil, "handstand", nil, "strict_pull_up", nil, "l_sit"])
    }

    func testInsertingIntoEmptySessionCreatesMinimalScaffold() {
        let draft = makeDraft(blocks: [])

        let updated = SkillBlockRouter.insert(
            skillID: "front_lever",
            title: "Front Lever",
            kind: .main,
            into: draft
        )

        XCTAssertEqual(updated.blocks.count, 1)
        XCTAssertEqual(updated.blocks[0].kind, .skill)
        XCTAssertEqual(updated.blocks[0].prescriptions.first?.rankStandardMovementId, "front_lever")
    }

    func testWorkoutBlockCarriesRegionLoad() {
        let block = SkillBlockRouter.workoutBlock(
            skillID: "muscle_up",
            title: "Muscle-Up",
            kind: .main
        )

        XCTAssertEqual(block.kind, .skill)
        XCTAssertEqual(block.skillKind, .main)
        XCTAssertEqual(block.regionLoad[.pull], 1.0)
        XCTAssertEqual(block.regionLoad[.shoulders], 0.5)
    }

    private func makeDraft(blocks: [TrainingBlock]) -> TrainingSessionDraft {
        TrainingSessionDraft(
            userId: "user-1",
            source: .program,
            title: "Program Day",
            estimatedMinutes: 45,
            blocks: blocks
        )
    }

    private func block(kind: TrainingBlockKind, title: String) -> TrainingBlock {
        TrainingBlock(
            kind: kind,
            title: title,
            prescriptions: [
                TrainingBlockPrescription(
                    exerciseName: title,
                    sets: 3,
                    target: .repsRange(8, 10),
                    restSeconds: 90,
                    muscleGroups: [.chest]
                )
            ]
        )
    }
}
