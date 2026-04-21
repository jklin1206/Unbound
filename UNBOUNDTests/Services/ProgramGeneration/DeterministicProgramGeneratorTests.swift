import XCTest
@testable import UNBOUND

final class DeterministicProgramGeneratorTests: XCTestCase {

    func testGeneratesExactlyFourteenDays() throws {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        XCTAssertEqual(program.days.count, 14)
    }

    func testTrainingDayCountMatchesTwiceTheFrequency() throws {
        let days: Set<Weekday> = [.monday, .wednesday, .friday]
        let input = makeInput(frequency: .three, trainingDays: days)
        let program = try DeterministicProgramGenerator.generate(input: input)
        let trainingCount = program.days.filter { !$0.isRestDay }.count
        XCTAssertEqual(trainingCount, 6) // 3/wk × 2 weeks
    }

    func testRestDaysHaveNoWorkout() throws {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        for day in program.days where day.isRestDay {
            XCTAssertNil(day.workout)
        }
    }

    func testTrainingDaysHaveWorkoutWithMainExercises() throws {
        let input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        let trainingDays = program.days.filter { !$0.isRestDay }
        for day in trainingDays {
            XCTAssertNotNil(day.workout, "day \(day.dayNumber) should have a workout")
            XCTAssertFalse(day.workout?.mainExercises.isEmpty ?? true,
                           "day \(day.dayNumber) mainExercises should not be empty")
        }
    }

    func testDurationDaysIsFourteen() throws {
        let input = makeInput(frequency: .three, trainingDays: [.monday, .wednesday, .friday])
        let program = try DeterministicProgramGenerator.generate(input: input)
        XCTAssertEqual(program.durationDays, 14)
    }

    func testCutModeShiftsNutrition() throws {
        var maintenance = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        maintenance.cutModeActive = false
        var cut = maintenance
        cut.cutModeActive = true

        let maintenanceProg = try DeterministicProgramGenerator.generate(input: maintenance)
        let cutProg = try DeterministicProgramGenerator.generate(input: cut)
        XCTAssertLessThan(cutProg.nutritionPlan.dailyCalories, maintenanceProg.nutritionPlan.dailyCalories)
    }

    func testWeakPointBiasInfluencesDayLabel() throws {
        var input = makeInput(frequency: .four, trainingDays: [.monday, .tuesday, .thursday, .friday])
        input.focusAreas = [
            FocusArea(muscleGroup: .shoulders, priority: 1, rationale: "narrow", suggestedFocus: "side delts")
        ]
        let program = try DeterministicProgramGenerator.generate(input: input)
        let labels = program.days.map(\.label).joined(separator: " | ")
        // At least one training day's label should mention shoulders (via bias naming).
        XCTAssertTrue(labels.lowercased().contains("shoulder"),
                      "At least one day's label should reference shoulders; got: \(labels)")
    }

    // MARK: — helper

    private func makeInput(frequency: TargetFrequency, trainingDays: Set<Weekday>) -> ProgramGeneratorInput {
        ProgramGeneratorInput(
            userId: "u-1",
            scanId: "s-1",
            analysisId: "a-1",
            archetype: .shredded,
            trainingStyle: .bodyweight,
            equipment: [.bodyweight],
            targetFrequency: frequency,
            trainingDays: trainingDays,
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
    }
}
