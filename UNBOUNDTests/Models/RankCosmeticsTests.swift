import XCTest
@testable import UNBOUND

final class RankCosmeticsTests: XCTestCase {
    func testEquippingRankCosmeticPostsProfileCosmeticsChangedForUser() {
        let userId = "rank-cosmetics-\(UUID().uuidString)"
        let expectation = expectation(description: "profile cosmetics notification")
        let token = NotificationCenter.default.addObserver(
            forName: .profileCosmeticsChanged,
            object: nil,
            queue: nil
        ) { note in
            guard note.userInfo?["userId"] as? String == userId else { return }
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        RankCosmetics.setEquippedFrameTier(.novice, userId: userId, currentTier: .novice)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(
            RankCosmetics.equippedFrameTier(userId: userId, currentTier: .novice),
            .novice
        )
    }
}
