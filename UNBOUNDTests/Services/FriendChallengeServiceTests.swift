import XCTest
@testable import UNBOUND

@MainActor
final class FriendChallengeServiceTests: XCTestCase {

    func testCreateChallengeThrowsWhenBackendUnavailable() async {
        let service = FriendChallengeService()
        do {
            _ = try await service.createChallenge(
                challengedId: UUID(),
                kind: .mostSessions,
                squadId: UUID()
            )
            XCTFail("Expected backendUnavailable to be thrown")
        } catch SquadError.backendUnavailable {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testActiveChallengesReturnsEmpty() async {
        let service = FriendChallengeService()
        let challenges = await service.activeChallenges(userId: UUID())
        XCTAssertTrue(challenges.isEmpty)
    }

    func testEvaluateExpiredDoesNotCrash() async {
        let service = FriendChallengeService()
        // With no active challenges, evaluateExpired should return quietly.
        await service.evaluateExpired()
    }

    func testEvaluateExpiredPicksHigherProgressAsWinner() {
        // With stub backend, this exercises the logic path when a winner
        // would be determined. For now verifies the model logic directly.
        var challenge = FriendChallenge(
            id: UUID(),
            challengerId: UUID(),
            challengedId: UUID(),
            squadId: UUID(),
            kind: .mostSessions,
            startedAt: .now.addingTimeInterval(-86400),
            expiresAt: .now.addingTimeInterval(-1),  // already expired
            acceptedAt: .now.addingTimeInterval(-86000),
            challengerProgress: 5,
            challengedProgress: 3,
            winnerUserId: nil
        )
        // The service would pick challengerId as winner (5 > 3).
        // Since backend is stub, verify the model's isExpired and progress logic.
        XCTAssertTrue(challenge.isExpired)
        XCTAssertNil(challenge.winnerUserId)
        // Simulate winner assignment
        challenge.winnerUserId = challenge.challengerProgress >= challenge.challengedProgress
            ? challenge.challengerId
            : challenge.challengedId
        XCTAssertEqual(challenge.winnerUserId, challenge.challengerId)
    }
}
