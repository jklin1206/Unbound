import XCTest
@testable import UNBOUND

@MainActor
final class SquadHonorsServiceTests: XCTestCase {

    func testRecordHonorPostsNotification() async {
        let service = SquadHonorsService()
        let honor = WeeklyHonor(
            id: UUID(),
            squadId: UUID(),
            weekIso: "2026-W20",
            kind: .ironWill,
            recipientUserId: UUID(),
            awardedAt: .now
        )

        var receivedHonor: WeeklyHonor?
        let expectation = expectation(description: "weeklyHonorReceived posted")
        let token = NotificationCenter.default.addObserver(
            forName: .weeklyHonorReceived,
            object: nil,
            queue: nil
        ) { notification in
            receivedHonor = notification.object as? WeeklyHonor
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        await service.recordHonor(honor)
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedHonor, honor)
    }

    func testCurrentHonorsReturnsEmpty() async {
        let service = SquadHonorsService()
        let honors = await service.currentHonors(squadId: UUID())
        XCTAssertTrue(honors.isEmpty, "currentHonors should return empty until backend is wired")
    }
}
