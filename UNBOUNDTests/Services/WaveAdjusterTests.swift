import XCTest
@testable import UNBOUND

final class WaveAdjusterTests: XCTestCase {
    func testDoesNotTriggerBeforeWaveTwo() {
        let program = makeProgram()
        let date = Calendar.fixedGMT.date(byAdding: .day, value: 13, to: program.createdAt)!

        let result = WaveAdjuster.applyIfNeeded(program: program, asOf: date, calendar: .fixedGMT)

        XCTAssertFalse(result.didApply)
        XCTAssertTrue(result.adjustments.isEmpty)
    }

    func testTriggersOnDayFifteenAndSkipsSavedWorkouts() {
        var program = makeProgram()
        program.days[2].savedWorkoutId = UUID()
        let date = Calendar.fixedGMT.date(byAdding: .day, value: 14, to: program.createdAt)!

        let result = WaveAdjuster.applyIfNeeded(program: program, asOf: date, calendar: .fixedGMT)

        XCTAssertTrue(result.didApply)
        XCTAssertEqual(result.adjustments.map(\.dayNumber), [15])
        XCTAssertEqual(result.adjustments.first?.reason.reasonCategory, .loadRaised)
        XCTAssertEqual(result.adjustments.first?.reason.revertible, true)
        XCTAssertNil(result.program.days[0].workout?.mainExercises.first?.rpe)
        XCTAssertEqual(result.program.days[1].workout?.mainExercises.first?.rpe, 8)
        XCTAssertNil(result.program.days[2].workout?.mainExercises.first?.rpe)
        XCTAssertTrue(result.program.days[1].workout?.notes?.contains("Wave 2 adjustment") == true)
    }

    func testDoesNotDoubleTriggerWhenAdjustmentIDAlreadyApplied() {
        let program = makeProgram()
        let date = Calendar.fixedGMT.date(byAdding: .day, value: 15, to: program.createdAt)!
        let arcId = try! XCTUnwrap(program.currentArc?.id)

        let result = WaveAdjuster.applyIfNeeded(
            program: program,
            asOf: date,
            appliedAdjustmentIDs: ["\(arcId):wave2:start"],
            calendar: .fixedGMT
        )

        XCTAssertFalse(result.didApply)
    }

    func testPerDayAdjustmentCanBeSuppressedWithoutHidingOtherRows() {
        let program = makeProgram()
        let date = Calendar.fixedGMT.date(byAdding: .day, value: 15, to: program.createdAt)!
        let arcId = try! XCTUnwrap(program.currentArc?.id)

        let result = WaveAdjuster.applyIfNeeded(
            program: program,
            asOf: date,
            appliedAdjustmentIDs: ["\(arcId):wave2:start:15"],
            calendar: .fixedGMT
        )

        XCTAssertTrue(result.didApply)
        XCTAssertEqual(result.adjustments.map(\.dayNumber), [16])
        XCTAssertNil(result.program.days[0].workout?.mainExercises.first?.rpe)
        XCTAssertNil(result.program.days[1].workout?.mainExercises.first?.rpe)
        XCTAssertEqual(result.program.days[2].workout?.mainExercises.first?.rpe, 8)
    }

    private func makeProgram() -> TrainingProgram {
        ProgramTestFactory.makeProgram(
            days: [
                ProgramTestFactory.makeDay(dayNumber: 14, label: "Push", role: .push, muscleGroups: [.chest]),
                ProgramTestFactory.makeDay(dayNumber: 15, label: "Pull", role: .pull, muscleGroups: [.back, .lats]),
                ProgramTestFactory.makeDay(dayNumber: 16, label: "Legs", role: .legs, muscleGroups: [.legs])
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            withArc: true
        )
    }
}
