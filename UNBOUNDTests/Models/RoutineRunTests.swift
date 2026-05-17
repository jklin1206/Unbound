import XCTest
@testable import UNBOUND

final class RoutineRunTests: XCTestCase {

    func testNotesAreFilteredOutOfRun() {
        let (run, notes) = RoutineRun.build([
            .instruction(text: "A", cue: nil),
            .note(text: "be careful"),
            .timed(label: "Hold", seconds: 30, style: .work)
        ])
        XCTAssertEqual(run.count, 2)
        XCTAssertEqual(notes, ["be careful"])
        XCTAssertNil(run[0].roundLabel)
        if case .note = run[0].kind { XCTFail("note leaked into run") }
        if case .note = run[1].kind { XCTFail("note leaked into run") }
    }

    func testCircuitExpandsWithRoundLabelsAndRestBetweenRounds() {
        let (run, _) = RoutineRun.build([
            .circuit(rounds: 3, restBetweenSeconds: 60, steps: [
                .instruction(text: "Push-ups × 15", cue: nil),
                .timed(label: "Plank", seconds: 45, style: .work)
            ])
        ])
        // 3 rounds × 2 steps = 6, + 2 inter-round rests (after r1, r2; not r3) = 8
        XCTAssertEqual(run.count, 8)
        XCTAssertEqual(run[0].roundLabel, "ROUND 1 / 3")
        XCTAssertEqual(run[1].roundLabel, "ROUND 1 / 3")
        if case .timed(_, let secs, let style) = run[2].kind {
            XCTAssertEqual(secs, 60)
            XCTAssertEqual(style, .rest)
        } else { XCTFail("expected inter-round rest at index 2") }
        XCTAssertEqual(run[3].roundLabel, "ROUND 2 / 3")
        XCTAssertEqual(run[7].roundLabel, "ROUND 3 / 3")
        if case .timed(_, _, let style) = run[7].kind {
            XCTAssertEqual(style, .work)
        } else { XCTFail("expected work step last") }
    }

    func testZeroRoundCircuitProducesEmpty() {
        let (run, _) = RoutineRun.build([
            .circuit(rounds: 0, restBetweenSeconds: 60, steps: [
                .instruction(text: "x", cue: nil)
            ])
        ])
        XCTAssertTrue(run.isEmpty)
    }

    func testIdsAreStableSequentialIndices() {
        let (run, _) = RoutineRun.build([
            .instruction(text: "A", cue: nil),
            .instruction(text: "B", cue: nil)
        ])
        XCTAssertEqual(run.map(\.id), [0, 1])
    }

    func testFlatSequencePreservesOrder() {
        let (run, _) = RoutineRun.build([
            .timed(label: "Warm", seconds: 120, style: .work),
            .interval(label: "HR", rounds: 5,
                      segments: [IntervalSegment(label: "GO", seconds: 60),
                                 IntervalSegment(label: "Easy", seconds: 60)]),
            .timed(label: "Cool", seconds: 180, style: .rest)
        ])
        XCTAssertEqual(run.count, 3)
        if case .interval = run[1].kind {} else { XCTFail("interval not preserved") }
    }
}
