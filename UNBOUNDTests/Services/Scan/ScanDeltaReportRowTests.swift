import XCTest
@testable import UNBOUND

final class ScanDeltaReportRowTests: XCTestCase {

    // Proof for the "frozen 5→5 grades" sub-issue: the scan-delta persistence
    // row must emit NO body grades, even when the in-memory report still carries
    // legacy neutral 5→5 BodyPartDelta values. The grade columns are nullable in
    // Postgres and must serialize as null.
    func test_scanDeltaRow_writesNoBodyGrades() throws {
        let neutral = BodyPartDelta(before: 5, after: 5)
        let report = ScanDeltaReport(
            id: "checkpoint-delta-a-b",
            userId: "u-1",
            baselineScanId: "a",
            comparisonScanId: "b",
            createdAt: Date(timeIntervalSince1970: 0),
            shoulders: neutral,
            chest: neutral,
            arms: neutral,
            core: neutral,
            legs: neutral,
            overall: neutral,
            narrative: "Checkpoint logged.",
            improvements: ["control"],
            laggingAreas: [],
            recommendedFocus: "Let logged sessions drive the next block."
        )

        let row = ScanDeltaReportRow(from: report)

        XCTAssertNil(row.shouldersBefore)
        XCTAssertNil(row.shouldersAfter)
        XCTAssertNil(row.chestBefore)
        XCTAssertNil(row.chestAfter)
        XCTAssertNil(row.armsBefore)
        XCTAssertNil(row.armsAfter)
        XCTAssertNil(row.coreBefore)
        XCTAssertNil(row.coreAfter)
        XCTAssertNil(row.legsBefore)
        XCTAssertNil(row.legsAfter)
        XCTAssertNil(row.overallBefore)
        XCTAssertNil(row.overallAfter)

        // Non-grade coaching payload still survives.
        XCTAssertEqual(row.narrative, "Checkpoint logged.")
        XCTAssertEqual(row.improvements, ["control"])
    }
}
