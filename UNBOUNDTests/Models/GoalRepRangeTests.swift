import XCTest
@testable import UNBOUND

final class GoalRepRangeTests: XCTestCase {
    func test_strength_isLowRep_forCompounds() {
        XCTAssertEqual(ExerciseClassification.upperCompound.defaultRepRange(for: .strength), 4...6)
        XCTAssertEqual(ExerciseClassification.lowerCompound.defaultRepRange(for: .strength), 4...6)
    }
    func test_hypertrophy_isModerateRep() {
        XCTAssertEqual(ExerciseClassification.upperCompound.defaultRepRange(for: .hypertrophy), 8...12)
        XCTAssertEqual(ExerciseClassification.accessory.defaultRepRange(for: .hypertrophy), 10...15)
    }
    func test_bodyweightRepTrack_variesByGoal() {
        XCTAssertEqual(ExerciseClassification.bodyweightSkill.defaultRepRange(for: .strength), 3...6)
        XCTAssertEqual(ExerciseClassification.bodyweightSkill.defaultRepRange(for: .skill), 5...8)
        XCTAssertEqual(ExerciseClassification.bodyweightSkill.defaultRepRange(for: .hypertrophy), 8...12)
    }
}
