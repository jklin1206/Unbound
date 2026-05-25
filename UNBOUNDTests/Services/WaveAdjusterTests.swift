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
        program.days[1].savedWorkoutId = UUID()
        let date = Calendar.fixedGMT.date(byAdding: .day, value: 14, to: program.createdAt)!

        let result = WaveAdjuster.applyIfNeeded(program: program, asOf: date, calendar: .fixedGMT)

        XCTAssertTrue(result.didApply)
        XCTAssertEqual(result.adjustments.map(\.dayNumber), [1])
        XCTAssertEqual(result.adjustments.first?.reason.reasonCategory, .loadRaised)
        XCTAssertEqual(result.adjustments.first?.reason.revertible, true)
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
            appliedAdjustmentIDs: ["\(arcId):wave2:start:1"],
            calendar: .fixedGMT
        )

        XCTAssertTrue(result.didApply)
        XCTAssertEqual(result.adjustments.map(\.dayNumber), [2])
    }

    private func makeProgram() -> TrainingProgram {
        ProgramTestFactory.makeProgram(
            days: [
                ProgramTestFactory.makeDay(dayNumber: 1, label: "Push", role: .push, muscleGroups: [.chest]),
                ProgramTestFactory.makeDay(dayNumber: 2, label: "Pull", role: .pull, muscleGroups: [.back, .lats])
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            withArc: true
        )
    }
}
