import XCTest
@testable import UNBOUND

final class ArcSchedulerTests: XCTestCase {
    func testMidArcContextShowsDayAndDaysRemaining() throws {
        let program = ProgramTestFactory.makeProgram(
            days: [ProgramTestFactory.makeDay(dayNumber: 1)],
            createdAt: Date(timeIntervalSince1970: 0),
            withArc: true
        )
        let date = Calendar.fixedGMT.date(byAdding: .day, value: 16, to: program.createdAt)!

        let context = try XCTUnwrap(ArcScheduler.context(for: program, asOf: date, calendar: .fixedGMT))

        XCTAssertEqual(context.dayNumber, 17)
        XCTAssertEqual(context.daysRemaining, Arc.durationDays - 17)
    }

    func testNextArcChainsSourceArc() throws {
        let program = ProgramTestFactory.makeProgram(
            days: [ProgramTestFactory.makeDay(dayNumber: 1)],
            createdAt: Date(timeIntervalSince1970: 0),
            withArc: true
        )
        let arc = try XCTUnwrap(program.currentArc)

        let next = ArcScheduler.nextArc(after: arc, programId: program.id, checkpoint: .skipped)

        XCTAssertEqual(next.sourceArcID, arc.id)
        XCTAssertEqual(next.startDate, arc.endDate)
        XCTAssertEqual(next.state, .active)
    }

    func testCheckpointOfferedAfterArcEnd() {
        let program = ProgramTestFactory.makeProgram(
            days: [ProgramTestFactory.makeDay(dayNumber: 1)],
            createdAt: Date(timeIntervalSince1970: 0),
            withArc: true
        )
        let date = Calendar.fixedGMT.date(byAdding: .day, value: Arc.durationDays, to: program.createdAt)!

        XCTAssertTrue(ArcScheduler.shouldOfferCheckpoint(program: program, asOf: date, calendar: .fixedGMT))
    }
}
