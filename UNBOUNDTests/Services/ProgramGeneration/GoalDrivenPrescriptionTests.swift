import XCTest
@testable import UNBOUND

/// Locks the 3a behavior change: prescriptions are driven by TrainingGoal (not a
/// per-day phase) and carry no RPE target.
final class GoalDrivenPrescriptionTests: XCTestCase {

    private func makeInput(goal: TrainingGoal) -> ProgramGeneratorInput {
        var input = ProgramGeneratorInput(
            userId: "u-goal",
            scanId: nil,
            analysisId: nil,
            buildIdentity: BuildIdentity(primary: .control, secondary: nil, shape: .specialist),
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            targetFrequency: .four,
            trainingDays: [.monday, .wednesday, .friday],
            experience: .current,
            focusAreas: [],
            cutModeActive: false,
            trainingFeedbackMode: .quick,
            progressionStates: [:],
            previousBlock: nil,
            weightKg: 75,
            heightCm: 178,
            age: 24,
            sex: .male,
            blockStartDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        input.goal = goal
        return input
    }

    func test_strengthGoal_lowRepPrimary_rpeFree() throws {
        let bench = try XCTUnwrap(MovementCatalog.canonicalExercise(named: "bench press"))
        let rx = DeterministicProgramGenerator.prescription(
            for: .strength, state: nil, isPrimary: true,
            fallbackRPE: 8, definition: bench, input: makeInput(goal: .strength))
        XCTAssertEqual(rx.reps, "4-6")
        XCTAssertEqual(rx.rpe, 0, "prescriptions no longer carry an RPE target")
    }

    func test_hypertrophyGoal_moderateRepPrimary_rpeFree() throws {
        let bench = try XCTUnwrap(MovementCatalog.canonicalExercise(named: "bench press"))
        let rx = DeterministicProgramGenerator.prescription(
            for: .hypertrophy, state: nil, isPrimary: true,
            fallbackRPE: 7, definition: bench, input: makeInput(goal: .hypertrophy))
        XCTAssertEqual(rx.reps, "8-12")
        XCTAssertEqual(rx.rpe, 0)
    }
}
