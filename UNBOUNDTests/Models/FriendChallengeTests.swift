import XCTest
@testable import UNBOUND

final class FriendChallengeTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let c = FriendChallenge(
            id: UUID(),
            challengerId: UUID(),
            challengedId: UUID(),
            squadId: UUID(),
            kind: .mostSessions,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_700_604_800),
            acceptedAt: nil,
            challengerProgress: 3,
            challengedProgress: 2,
            winnerUserId: nil
        )
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(FriendChallenge.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    func testIsActiveTrueWhenNoWinnerAndNotExpired() {
        let c = FriendChallenge(
            id: UUID(), challengerId: UUID(), challengedId: UUID(), squadId: UUID(),
            kind: .mostSessions,
            startedAt: .now.addingTimeInterval(-3600),
            expiresAt: .now.addingTimeInterval(3600),
            acceptedAt: .now,
            challengerProgress: 1,
            challengedProgress: 0,
            winnerUserId: nil
        )
        XCTAssertTrue(c.isActive)
        XCTAssertFalse(c.isExpired)
    }

    func testIsExpiredTrueAfterExpiry() {
        let c = FriendChallenge(
            id: UUID(), challengerId: UUID(), challengedId: UUID(), squadId: UUID(),
            kind: .mostSessions,
            startedAt: .now.addingTimeInterval(-7200),
            expiresAt: .now.addingTimeInterval(-1),
            acceptedAt: .now.addingTimeInterval(-7000),
            challengerProgress: 2,
            challengedProgress: 3,
            winnerUserId: nil
        )
        XCTAssertTrue(c.isExpired)
        XCTAssertFalse(c.isActive)
    }

    func testIsPendingWhenNotAccepted() {
        let c = FriendChallenge(
            id: UUID(), challengerId: UUID(), challengedId: UUID(), squadId: UUID(),
            kind: .earlyRiser,
            startedAt: .now,
            expiresAt: .now.addingTimeInterval(86400),
            acceptedAt: nil,
            challengerProgress: 0,
            challengedProgress: 0,
            winnerUserId: nil
        )
        XCTAssertTrue(c.isPending)
    }

    func testAllKindsHaveDisplayName() {
        for kind in FriendChallenge.Kind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty)
            XCTAssertFalse(kind.subtitle.isEmpty)
        }
    }

    func testSixKindsPresent() {
        XCTAssertEqual(FriendChallenge.Kind.allCases.count, 6)
    }
}
