import XCTest
@testable import UNBOUND

final class RestPrescriptionTests: XCTestCase {
    private func ex(name: String, muscles: [MuscleGroup], rest: Int) -> Exercise {
        Exercise(id: "x", name: name, muscleGroups: muscles, sets: 3,
                 reps: "8", restSeconds: rest, rpe: nil, notes: nil, substitution: nil)
    }
    func test_explicitRestWins_whenSane() {
        XCTAssertEqual(RestPrescription.restSeconds(for: ex(name: "Bench Press", muscles: [.chest], rest: 120)), 120)
    }
    func test_zeroOrInsaneRest_fallsBackToClassification() {
        XCTAssertEqual(RestPrescription.restSeconds(for: ex(name: "Back Squat", muscles: [.legs], rest: 0)), 150)
        XCTAssertEqual(RestPrescription.restSeconds(for: ex(name: "Cable Curl", muscles: [.arms], rest: 0)), 90)
        XCTAssertEqual(RestPrescription.restSeconds(for: ex(name: "Cable Curl", muscles: [.arms], rest: 5000)), 90)
    }
    func test_multiMuscleCountsAsCompound() {
        XCTAssertEqual(RestPrescription.restSeconds(for: ex(name: "Pendlay", muscles: [.back, .arms], rest: 0)), 150)
    }
}
