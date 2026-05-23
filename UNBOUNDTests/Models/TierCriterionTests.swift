import XCTest
@testable import UNBOUND

final class TierCriterionTests: XCTestCase {
    func testRepsRoundtrip() throws {
        let c: TierCriterion = .reps(8, exerciseName: "pull-up")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testSecondsRoundtrip() throws {
        let c: TierCriterion = .seconds(60)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testWeightKgRoundtrip() throws {
        let c: TierCriterion = .weightKg(120.0)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testExerciseWeightKgRoundtrip() throws {
        let c: TierCriterion = .exerciseWeightKg(85.0, exerciseName: "bench press")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testBodyweightRatioRoundtrip() throws {
        let c: TierCriterion = .bodyweightRatio(1.5)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testExerciseBodyweightRatioRoundtrip() throws {
        let c: TierCriterion = .exerciseBodyweightRatio(0.5, exerciseName: "weighted pullup")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testVariantRoundtrip() throws {
        let c: TierCriterion = .variant("muscle-up")
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testCompoundRoundtrip() throws {
        let c: TierCriterion = .compound([
            .reps(8, exerciseName: "pull-up"),
            .seconds(30)
        ])
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(TierCriterion.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testEquatability() {
        XCTAssertEqual(TierCriterion.reps(8, exerciseName: "pull-up"),
                       TierCriterion.reps(8, exerciseName: "pull-up"))
        XCTAssertNotEqual(TierCriterion.reps(8, exerciseName: "pull-up"),
                          TierCriterion.reps(8, exerciseName: "chin-up"))
        XCTAssertNotEqual(TierCriterion.seconds(60), TierCriterion.seconds(61))
    }

    func testStrictPullupProofDoesNotAcceptRegressionVariants() {
        XCTAssertTrue(
            TierCriterionEvaluator.satisfied(
                criterion: .reps(1, exerciseName: "pullup"),
                history: [exercise("Pull-Up", movementId: "exercise.pullup", reps: 1)],
                bodyweightKg: 75
            )
        )

        XCTAssertFalse(
            TierCriterionEvaluator.satisfied(
                criterion: .reps(1, exerciseName: "pullup"),
                history: [
                    exercise(
                        "Band-Assisted Pull-Up",
                        movementId: "exercise.pullup",
                        rankStandardMovementId: "exercise.pullup",
                        reps: 12
                    )
                ],
                bodyweightKg: 75
            ),
            "Old logs that accidentally stored assisted work under the pullup movement ID must not prove strict pullup tiers."
        )

        XCTAssertFalse(
            TierCriterionEvaluator.satisfied(
                criterion: .reps(1, exerciseName: "pullup"),
                history: [exercise("Tempo Negative Pull-Up", movementId: "exercise.negative-pullup", reps: 5)],
                bodyweightKg: 75
            )
        )

        XCTAssertTrue(
            TierCriterionEvaluator.satisfied(
                criterion: .reps(3, exerciseName: "negative pullup"),
                history: [exercise("Tempo Negative Pull-Up", movementId: "exercise.negative-pullup", reps: 3)],
                bodyweightKg: 75
            )
        )
    }

    private func exercise(
        _ name: String,
        movementId: String? = nil,
        rankStandardMovementId: String? = nil,
        reps: Int
    ) -> ExerciseLogEntry {
        ExerciseLogEntry(
            id: UUID().uuidString,
            exerciseName: name,
            movementId: movementId,
            rankStandardMovementId: rankStandardMovementId ?? movementId,
            plannedSets: 1,
            plannedReps: "\(reps)",
            sets: [
                SetLog(
                    id: UUID().uuidString,
                    setNumber: 1,
                    weightKg: nil,
                    reps: reps,
                    rpe: nil,
                    isWarmup: false
                )
            ],
            skipped: false,
            notes: nil
        )
    }
}
