import XCTest
@testable import UNBOUND

final class ArcGeneratorTests: XCTestCase {
    func testNextArcSkippedCheckpointPreservesSavedWorkoutOwnershipAndChainsArc() throws {
        var program = ProgramTestFactory.makeProgram(
            days: [
                ProgramTestFactory.makeDay(dayNumber: 1, label: "Push", role: .push, muscleGroups: [.chest]),
                ProgramTestFactory.makeDay(dayNumber: 2, label: "Pull", role: .pull, muscleGroups: [.back, .lats])
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            withArc: true
        )
        let savedID = UUID()
        program.days[1].savedWorkoutId = savedID
        let sourceArc = try XCTUnwrap(program.currentArc)

        let next = ArcGenerator.generateNextArc(from: program, checkpoint: .skipped)

        XCTAssertEqual(next.arcs.count, 2)
        XCTAssertEqual(next.currentArc?.sourceArcID, sourceArc.id)
        XCTAssertEqual(next.days[1].savedWorkoutId, savedID)
        XCTAssertEqual(next.rationale?.decisions.first?.reasonCategory, .checkpointRecommendation)
    }

    func testCompletedCheckpointProducesLoadReasonWithoutChangingSplitShape() {
        let program = ProgramTestFactory.makeProgram(
            days: [
                ProgramTestFactory.makeDay(dayNumber: 1, label: "Push", role: .push, muscleGroups: [.chest]),
                ProgramTestFactory.makeDay(dayNumber: 2, label: "Pull", role: .pull, muscleGroups: [.back, .lats])
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            withArc: true
        )
        let signals = CheckpointSignals(
            loadAdjustmentBias: -0.24,
            recoveryStateHint: .accumulated,
            weakRegions: [.lats],
            freeTextSummary: "Pull volume was hard."
        )

        let next = ArcGenerator.generateNextArc(from: program, checkpoint: .completed(signals))

        XCTAssertEqual(Array(next.days.map(\.sessionRole).prefix(2)), [.push, .pull])
        XCTAssertEqual(next.rationale?.decisions.first?.reasonCategory, .loadLowered)
        XCTAssertEqual(next.rationale?.decisions.first?.revertible, false)
    }
}
