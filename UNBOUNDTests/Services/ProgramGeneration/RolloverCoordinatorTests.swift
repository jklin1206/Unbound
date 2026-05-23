import XCTest
@testable import UNBOUND

final class RolloverCoordinatorTests: XCTestCase {
    private func decide(daysRemaining: Int, freshScan: Bool, daysPastBoundary: Int)
        -> RolloverCoordinator.Decision {
        RolloverCoordinator.decide(
            daysRemaining: daysRemaining, hasFreshScan: freshScan,
            daysPastBoundary: daysPastBoundary, graceDays: 5)
    }

    func test_before_boundary_is_noop() {
        XCTAssertEqual(decide(daysRemaining: 3, freshScan: false, daysPastBoundary: 0), .noop)
    }
    func test_boundary_with_fresh_scan_rolls_now() {
        XCTAssertEqual(decide(daysRemaining: 0, freshScan: true, daysPastBoundary: 0), .rollNow)
    }
    func test_boundary_no_scan_awaits() {
        XCTAssertEqual(decide(daysRemaining: 0, freshScan: false, daysPastBoundary: 0), .awaitRescan)
    }
    func test_grace_expired_no_scan_auto_rolls() {
        XCTAssertEqual(decide(daysRemaining: 0, freshScan: false, daysPastBoundary: 6), .rollNow)
    }
}
