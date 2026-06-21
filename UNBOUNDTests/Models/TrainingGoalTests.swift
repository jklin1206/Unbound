import XCTest
@testable import UNBOUND

final class TrainingGoalTests: XCTestCase {
    func test_derivesFromProgramTemplateKey() {
        XCTAssertEqual(TrainingGoal.from(programTemplateKey: "power"), .strength)
        XCTAssertEqual(TrainingGoal.from(programTemplateKey: "control"), .skill)
        XCTAssertEqual(TrainingGoal.from(programTemplateKey: "endurance"), .hypertrophy)
        XCTAssertEqual(TrainingGoal.from(programTemplateKey: "balanced"), .hypertrophy)
    }
    func test_unknownKeyFallsBackToHypertrophy() {
        XCTAssertEqual(TrainingGoal.from(programTemplateKey: "anything-else"), .hypertrophy)
    }
}
