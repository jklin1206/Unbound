import XCTest
@testable import UNBOUND

final class RoutineStepTests: XCTestCase {
    private func roundTrip(_ step: RoutineStep) throws -> RoutineStep {
        let data = try JSONEncoder().encode(step)
        return try JSONDecoder().decode(RoutineStep.self, from: data)
    }

    func testInstructionRoundTrips() throws {
        let s = RoutineStep.instruction(text: "Push-ups × 15", cue: "elbows 45°")
        XCTAssertEqual(try roundTrip(s), s)
    }

    func testTimedRoundTrips() throws {
        let s = RoutineStep.timed(label: "Plank", seconds: 60, style: .work)
        XCTAssertEqual(try roundTrip(s), s)
    }

    func testIntervalRoundTrips() throws {
        let s = RoutineStep.interval(
            label: "Tabata",
            rounds: 8,
            segments: [IntervalSegment(label: "WORK", seconds: 20),
                       IntervalSegment(label: "REST", seconds: 10)]
        )
        XCTAssertEqual(try roundTrip(s), s)
    }

    func testRepTargetRoundTrips() throws {
        XCTAssertEqual(try roundTrip(.repTarget(name: "Push-ups", target: 100, cue: nil)),
                       .repTarget(name: "Push-ups", target: 100, cue: nil))
        XCTAssertEqual(try roundTrip(.repTarget(name: "Push-ups", target: nil, cue: "AMRAP")),
                       .repTarget(name: "Push-ups", target: nil, cue: "AMRAP"))
    }

    func testNestedCircuitRoundTrips() throws {
        let s = RoutineStep.circuit(
            rounds: 3,
            restBetweenSeconds: 60,
            steps: [.instruction(text: "Squats × 20", cue: nil),
                    .timed(label: "Plank", seconds: 45, style: .work)]
        )
        XCTAssertEqual(try roundTrip(s), s)
    }

    func testNoteRoundTrips() throws {
        let s = RoutineStep.note(text: "Warning: most people DNF after Gate 5.")
        XCTAssertEqual(try roundTrip(s), s)
    }
}
