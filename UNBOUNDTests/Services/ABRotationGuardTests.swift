import XCTest
@testable import UNBOUND

final class ABRotationGuardTests: XCTestCase {
    func testSameRoleCanPair() {
        let a = saved(title: "Push A", role: "push")
        let b = saved(title: "Push B", role: "push")

        XCTAssertTrue(ABRotationGuard.canPair(a, with: b))
        XCTAssertNil(ABRotationGuard.validate(a, with: b).reason)
    }

    func testDifferentRoleRejectsWithReason() {
        let a = saved(title: "Push A", role: "push")
        let b = saved(title: "Legs B", role: "legs")

        let result = ABRotationGuard.validate(a, with: b)

        XCTAssertFalse(result.canPair)
        XCTAssertEqual(result.reason, .differentRole("push", "legs"))
    }

    func testMatchingCustomRoleCanPair() {
        let a = saved(title: "Evening A", role: "custom:evening-mobility")
        let b = saved(title: "Evening B", role: "custom:evening-mobility")

        XCTAssertTrue(ABRotationGuard.canPair(a, with: b))
    }

    private func saved(title: String, role: String?) -> SavedWorkout {
        SavedWorkout(
            title: title,
            blocks: [
                TrainingBlock(
                    kind: .strength,
                    title: title,
                    prescriptions: [
                        TrainingBlockPrescription(
                            exerciseName: title,
                            sets: 3,
                            target: .repsRange(8, 10),
                            restSeconds: 90
                        )
                    ]
                )
            ],
            sessionRole: role
        )
    }
}
