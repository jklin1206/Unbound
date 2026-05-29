import XCTest
@testable import UNBOUND

final class RealizationGateTests: XCTestCase {

    // Rank-gated peaking: realization at B-, peaking at A-. Weeks 1-8 are
    // rank-independent; weeks 9-11 are where ability gates the block.

    func testBelowBMinusNeverRealizesOrPeaks() {
        // < B- : weeks 9-11 stay intensification, week 12 deload.
        for week in 9...11 {
            let block = LocalProgramGenerator.scheduledBlock(
                week: week, realizationUnlocked: false, peakingUnlocked: false
            )
            XCTAssertEqual(block, .intensification, "Week \(week) must not realize below B-")
        }
        XCTAssertEqual(
            LocalProgramGenerator.scheduledBlock(week: 12, realizationUnlocked: false, peakingUnlocked: false),
            .deload
        )
    }

    func testBMinusEmitsRealizationButNotPeaking() {
        // B- : weeks 9-11 realization, week 12 deload, no peaking.
        for week in 9...11 {
            XCTAssertEqual(
                LocalProgramGenerator.scheduledBlock(week: week, realizationUnlocked: true, peakingUnlocked: false),
                .realization,
                "Week \(week) must realize at B-"
            )
        }
    }

    func testAMinusEmitsPeakingWeek11() {
        // A- : weeks 9-10 realization, week 11 peaking.
        XCTAssertEqual(
            LocalProgramGenerator.scheduledBlock(week: 9, realizationUnlocked: true, peakingUnlocked: true),
            .realization
        )
        XCTAssertEqual(
            LocalProgramGenerator.scheduledBlock(week: 11, realizationUnlocked: true, peakingUnlocked: true),
            .peaking,
            "Week 11 must peak at A-"
        )
    }

    func testEarlyWeeksAreRankIndependent() {
        XCTAssertEqual(LocalProgramGenerator.scheduledBlock(week: 1, realizationUnlocked: true, peakingUnlocked: true), .accumulation)
        XCTAssertEqual(LocalProgramGenerator.scheduledBlock(week: 6, realizationUnlocked: true, peakingUnlocked: true), .intensification)
    }
}
