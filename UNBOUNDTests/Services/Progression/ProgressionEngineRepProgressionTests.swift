import XCTest
@testable import UNBOUND

@MainActor
final class ProgressionEngineRepProgressionTests: XCTestCase {

    func test_hitsTarget_atOrAboveTopOfRange_regardlessOfRPE() {
        // Top of range reached → hit, with no RPE involved at all.
        XCTAssertTrue(ProgressionEngine.sessionHitsTarget(bestSetReps: 12, targetRepMax: 12))
        XCTAssertTrue(ProgressionEngine.sessionHitsTarget(bestSetReps: 15, targetRepMax: 12))
    }

    func test_doesNotHitTarget_belowTopOfRange() {
        XCTAssertFalse(ProgressionEngine.sessionHitsTarget(bestSetReps: 11, targetRepMax: 12))
        XCTAssertFalse(ProgressionEngine.sessionHitsTarget(bestSetReps: 0, targetRepMax: 8))
    }
}
