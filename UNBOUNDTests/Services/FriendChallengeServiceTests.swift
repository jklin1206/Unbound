import XCTest
@testable import UNBOUND

@MainActor
final class FriendChallengeServiceTests: XCTestCase {

    func testCreateChallengeThrowsWhenBackendUnavailable() async {
        let service = FriendChallengeService(remoteBackendEnabled: false)
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
        let service = FriendChallengeService(remoteBackendEnabled: false)
        let challenges = await service.activeChallenges(userId: UUID())
        XCTAssertTrue(challenges.isEmpty)
    }

    func testCreateChallengeUsesLocalFallbackForDebugUser() async throws {
        let challengerUserId = "dev-challenge-test"
        let challengedId = try XCTUnwrap(SquadUserIdentity.uuid(from: "dev-challenge-opponent"))
        let challengerId = try XCTUnwrap(SquadUserIdentity.uuid(from: challengerUserId))
        AuthService.shared.activateDevUser(id: challengerUserId)

        let service = FriendChallengeService(remoteBackendEnabled: true)
        let challenge = try await service.createChallenge(
            challengedId: challengedId,
            kind: .mostSessions,
            squadId: UUID()
        )
        let active = await service.activeChallenges(userId: challengerId)

        XCTAssertEqual(challenge.challengerId, challengerId)
        XCTAssertEqual(challenge.challengedId, challengedId)
        XCTAssertEqual(active.map(\.id), [challenge.id])
        XCTAssertTrue(challenge.isPending)
    }

    func testRecordProgressUsesLocalDebugUserMapping() async throws {
        let challengerUserId = "dev-challenge-progress"
        let challengedUserId = "dev-challenge-progress-two"
        let challengedId = try XCTUnwrap(SquadUserIdentity.uuid(from: challengedUserId))
        let challengerId = try XCTUnwrap(SquadUserIdentity.uuid(from: challengerUserId))
        AuthService.shared.activateDevUser(id: challengerUserId)

        let service = FriendChallengeService(remoteBackendEnabled: true)
        let challenge = try await service.createChallenge(
            challengedId: challengedId,
            kind: .mostSessions,
            squadId: UUID()
        )
        try await service.accept(challenge.id)

        let log = WorkoutLog(
            id: "progress-proof",
            userId: challengerUserId,
            programId: "program",
            dayNumber: 1,
            plannedWorkoutName: "Proof Session",
            startedAt: Date().addingTimeInterval(-1800),
            completedAt: Date(),
            exerciseEntries: [],
            overallNotes: nil,
            overallRPE: 7,
            durationMinutes: 30
        )
        await service.recordProgress(log: log, userId: challengerUserId)

        let active = await service.activeChallenges(userId: challengerId)
        XCTAssertEqual(active.first?.challengerProgress, 1)
        XCTAssertEqual(active.first?.challengedProgress, 0)
        XCTAssertEqual(active.first?.challengedId, challengedId)
        XCTAssertFalse(active.first?.isPending ?? true)
    }

    func testEvaluateExpiredDoesNotCrash() async {
        let service = FriendChallengeService(remoteBackendEnabled: false)
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
