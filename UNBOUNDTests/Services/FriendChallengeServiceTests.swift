import XCTest
@testable import UNBOUND

@MainActor
final class FriendChallengeServiceTests: XCTestCase {
    private func makeLog(
        id: String,
        userId: String,
        localStartHour: Int? = nil
    ) -> WorkoutLog {
        WorkoutLog(
            id: id,
            userId: userId,
            programId: "program",
            dayNumber: 1,
            plannedWorkoutName: "Proof Session",
            startedAt: Date().addingTimeInterval(-1800),
            completedAt: Date(),
            exerciseEntries: [],
            overallNotes: nil,
            overallRPE: 7,
            durationMinutes: 30,
            localStartHour: localStartHour
        )
    }

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

    func testCreateChallengeRejectsHeaviestLiftWithoutExerciseBeforeBackend() async {
        let service = FriendChallengeService(remoteBackendEnabled: false)
        do {
            _ = try await service.createChallenge(
                challengedId: UUID(),
                kind: .heaviestLift,
                squadId: UUID(),
                exerciseName: nil
            )
            XCTFail("Expected unsupportedChallengeKind to be thrown")
        } catch SquadError.unsupportedChallengeKind {
            // Expected: heaviestLift requires a non-blank exercise name.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // A blank/whitespace exercise name is also rejected.
        do {
            _ = try await service.createChallenge(
                challengedId: UUID(),
                kind: .heaviestLift,
                squadId: UUID(),
                exerciseName: "   "
            )
            XCTFail("Expected unsupportedChallengeKind for blank exercise name")
        } catch SquadError.unsupportedChallengeKind {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDeclineRemovesLocalChallengeAndPostsNotification() async throws {
        // Dev (non-UUID) auth id keeps decline + activeChallenges on the local
        // path, so removal is observable without a backend.
        let challengedUserId = "dev-challenge-decline"
        let me = try XCTUnwrap(SquadUserIdentity.uuid(from: challengedUserId))
        AuthService.shared.activateDevUser(id: challengedUserId)

        let service = FriendChallengeService(remoteBackendEnabled: true)
        let challenge = FriendChallenge(
            id: UUID(),
            challengerId: UUID(),
            challengedId: me,
            squadId: UUID(),
            kind: .mostSessions,
            exerciseName: nil,
            startedAt: Date(),
            expiresAt: Date().addingTimeInterval(6 * 86_400),
            acceptedAt: nil,
            challengerProgress: 0,
            challengedProgress: 0,
            winnerUserId: nil
        )
        service._seedLocalChallengeForTesting(challenge)
        let seeded = await service.activeChallenges(userId: me)
        XCTAssertEqual(seeded.map(\.id), [challenge.id])

        let declined = expectation(forNotification: .friendChallengeDeclined, object: nil)
        try await service.decline(challenge.id)

        await fulfillment(of: [declined], timeout: 1)
        let remaining = await service.activeChallenges(userId: me)
        XCTAssertFalse(remaining.contains { $0.id == challenge.id })
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

        let log = makeLog(id: "progress-proof", userId: challengerUserId)
        await service.recordProgress(log: log, userId: challengerUserId, sourceLogId: "progress-proof")

        let active = await service.activeChallenges(userId: challengerId)
        XCTAssertEqual(active.first?.challengerProgress, 1)
        XCTAssertEqual(active.first?.challengedProgress, 0)
        XCTAssertEqual(active.first?.challengedId, challengedId)
        XCTAssertFalse(active.first?.isPending ?? true)
    }

    func testRecordProgressCountsEarlyRiserFromLocalStartHour() async throws {
        let challengerUserId = "dev-early-riser-progress"
        let challengedId = try XCTUnwrap(SquadUserIdentity.uuid(from: "dev-early-riser-opponent"))
        let challengerId = try XCTUnwrap(SquadUserIdentity.uuid(from: challengerUserId))
        AuthService.shared.activateDevUser(id: challengerUserId)

        let service = FriendChallengeService(remoteBackendEnabled: true)
        let challenge = try await service.createChallenge(
            challengedId: challengedId,
            kind: .earlyRiser,
            squadId: UUID()
        )
        try await service.accept(challenge.id)

        await service.recordProgress(
            log: makeLog(id: "early-proof", userId: challengerUserId, localStartHour: 7),
            userId: challengerUserId,
            sourceLogId: "early-proof"
        )
        await service.recordProgress(
            log: makeLog(id: "late-proof", userId: challengerUserId, localStartHour: 8),
            userId: challengerUserId,
            sourceLogId: "late-proof"
        )

        let active = await service.activeChallenges(userId: challengerId)
        XCTAssertEqual(active.first?.challengerProgress, 1)
        XCTAssertEqual(active.first?.challengedProgress, 0)
    }

    func testRecordProgressSignalsHeaviestLiftLocalChallenge() async throws {
        // Every v2 kind records a +1 signal locally (the server computes the real
        // weighted/MAX delta); nothing is skipped as "unsupported" anymore.
        let challengerUserId = "dev-heaviest-challenge-progress"
        let challengerId = try XCTUnwrap(SquadUserIdentity.uuid(from: challengerUserId))
        let challengedId = try XCTUnwrap(SquadUserIdentity.uuid(from: "dev-heaviest-challenge-opponent"))
        AuthService.shared.activateDevUser(id: challengerUserId)

        let service = FriendChallengeService(remoteBackendEnabled: true)
        service._seedLocalChallengeForTesting(FriendChallenge(
            id: UUID(),
            challengerId: challengerId,
            challengedId: challengedId,
            squadId: UUID(),
            kind: .heaviestLift,
            exerciseName: "Bench Press",
            startedAt: .now.addingTimeInterval(-3600),
            expiresAt: .now.addingTimeInterval(3600),
            acceptedAt: .now,
            challengerProgress: 0,
            challengedProgress: 0,
            winnerUserId: nil
        ))

        await service.recordProgress(
            log: makeLog(id: "heaviest-proof", userId: challengerUserId, localStartHour: 6),
            userId: challengerUserId,
            sourceLogId: "heaviest-proof"
        )

        let active = await service.activeChallenges(userId: challengerId)
        XCTAssertEqual(active.first?.challengerProgress, 1)
        XCTAssertEqual(active.first?.challengedProgress, 0)
        XCTAssertEqual(active.first?.exerciseName, "Bench Press")
    }

    func testEvaluateExpiredDoesNotCrash() async {
        let service = FriendChallengeService(remoteBackendEnabled: false)
        // With no active challenges, evaluateExpired should return quietly.
        await service.evaluateExpired()
    }

    func testEvaluateExpiredClosesPastDeadlineChallengeWithWinner() async throws {
        let challengerUserId = "dev-expire-winner"
        AuthService.shared.activateDevUser(id: challengerUserId)
        let challengerId = try XCTUnwrap(SquadUserIdentity.uuid(from: challengerUserId))
        let challengedId = try XCTUnwrap(SquadUserIdentity.uuid(from: "dev-expire-loser"))

        let service = FriendChallengeService(remoteBackendEnabled: true)
        let expired = FriendChallenge(
            id: UUID(),
            challengerId: challengerId,
            challengedId: challengedId,
            squadId: UUID(),
            kind: .mostSessions,
            exerciseName: nil,
            startedAt: .now.addingTimeInterval(-8 * 24 * 3600),
            expiresAt: .now.addingTimeInterval(-1),  // already past deadline
            acceptedAt: .now.addingTimeInterval(-7 * 24 * 3600),
            challengerProgress: 5,
            challengedProgress: 2,
            winnerUserId: nil
        )
        service._seedLocalChallengeForTesting(expired)

        var receivedWinner: UUID? = nil
        let expectation = XCTestExpectation(description: ".friendChallengeExpired posted")
        let token = NotificationCenter.default.addObserver(
            forName: .friendChallengeExpired, object: nil, queue: .main
        ) { note in
            receivedWinner = (note.object as? FriendChallenge)?.winnerUserId
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        await service.evaluateExpired()

        await fulfillment(of: [expectation], timeout: 1.0)
        // Higher progress (5 > 2) → challenger wins.
        XCTAssertEqual(receivedWinner, challengerId)
        // Challenge is now closed: no longer active.
        let active = await service.activeChallenges(userId: challengerId)
        XCTAssertTrue(active.isEmpty, "Closed challenge should not appear as active")
    }

    // SHOULD-FIX 5 proof: a second settle of the same challenge is a no-op.
    // evaluateExpired runs on every scenePhase .active with no throttle, so two
    // rapid foregrounds must not double-post .friendChallengeExpired. The local
    // path guards on winnerUserId == nil (mirroring the remote
    // `.is("winner_user_id", nil)` UPDATE filter), so the second pass skips the
    // already-settled challenge.
    func testEvaluateExpiredIsIdempotentAcrossConcurrentSettles() async throws {
        let challengerUserId = "dev-expire-idempotent"
        AuthService.shared.activateDevUser(id: challengerUserId)
        let challengerId = try XCTUnwrap(SquadUserIdentity.uuid(from: challengerUserId))
        let challengedId = try XCTUnwrap(SquadUserIdentity.uuid(from: "dev-expire-idempotent-loser"))

        let service = FriendChallengeService(remoteBackendEnabled: true)
        let expired = FriendChallenge(
            id: UUID(),
            challengerId: challengerId,
            challengedId: challengedId,
            squadId: UUID(),
            kind: .mostSessions,
            exerciseName: nil,
            startedAt: .now.addingTimeInterval(-8 * 24 * 3600),
            expiresAt: .now.addingTimeInterval(-1),
            acceptedAt: .now.addingTimeInterval(-7 * 24 * 3600),
            challengerProgress: 4,
            challengedProgress: 1,
            winnerUserId: nil
        )
        service._seedLocalChallengeForTesting(expired)

        var postCount = 0
        let token = NotificationCenter.default.addObserver(
            forName: .friendChallengeExpired, object: nil, queue: .main
        ) { _ in postCount += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        // Two rapid foregrounds.
        await service.evaluateExpired()
        await service.evaluateExpired()
        // Let any queued main-thread posts drain.
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(postCount, 1, "Second settle must be a no-op")
    }

    // The 120-Arc duel-win reward is paid in the service settle path (not the
    // toast, which may never mount). evaluateExpired runs on every foreground, so
    // the wallet's sourceId ledger must keep the payout exactly-once.
    func testSettleGrantsDuelWinArcsToWinnerExactlyOnce() async throws {
        let challengerUserId = "dev-duel-grant-\(UUID().uuidString)"
        AuthService.shared.activateDevUser(id: challengerUserId)
        let challengerId = try XCTUnwrap(SquadUserIdentity.uuid(from: challengerUserId))
        let challengedId = try XCTUnwrap(SquadUserIdentity.uuid(from: "dev-duel-grant-loser"))

        let wallet = CurrencyWalletStore.shared
        wallet.bind(userId: challengerUserId)
        let before = wallet.balance

        let service = FriendChallengeService(remoteBackendEnabled: true)
        service._seedLocalChallengeForTesting(FriendChallenge(
            id: UUID(),
            challengerId: challengerId,
            challengedId: challengedId,
            squadId: UUID(),
            kind: .mostSessions,
            exerciseName: nil,
            startedAt: .now.addingTimeInterval(-8 * 24 * 3600),
            expiresAt: .now.addingTimeInterval(-1),
            acceptedAt: .now.addingTimeInterval(-7 * 24 * 3600),
            challengerProgress: 5,   // challenger (the signed-in user) wins
            challengedProgress: 2,
            winnerUserId: nil
        ))

        // Two rapid foregrounds must pay the winner exactly once.
        await service.evaluateExpired()
        await service.evaluateExpired()

        wallet.bind(userId: challengerUserId)   // re-read persisted balance
        XCTAssertEqual(wallet.balance, before + SquadRewardPolicy.duelWinArcs)
    }

    func testSettleDoesNotPayArcsToLoser() async throws {
        let challengerUserId = "dev-duel-loss-\(UUID().uuidString)"
        AuthService.shared.activateDevUser(id: challengerUserId)
        let challengerId = try XCTUnwrap(SquadUserIdentity.uuid(from: challengerUserId))
        let challengedId = try XCTUnwrap(SquadUserIdentity.uuid(from: "dev-duel-loss-winner"))

        let wallet = CurrencyWalletStore.shared
        wallet.bind(userId: challengerUserId)
        let before = wallet.balance

        let service = FriendChallengeService(remoteBackendEnabled: true)
        service._seedLocalChallengeForTesting(FriendChallenge(
            id: UUID(),
            challengerId: challengerId,
            challengedId: challengedId,
            squadId: UUID(),
            kind: .mostSessions,
            exerciseName: nil,
            startedAt: .now.addingTimeInterval(-8 * 24 * 3600),
            expiresAt: .now.addingTimeInterval(-1),
            acceptedAt: .now.addingTimeInterval(-7 * 24 * 3600),
            challengerProgress: 1,   // challenger (the signed-in user) loses
            challengedProgress: 4,
            winnerUserId: nil
        ))

        await service.evaluateExpired()

        wallet.bind(userId: challengerUserId)
        XCTAssertEqual(wallet.balance, before, "A loser is never paid the duel-win reward")
    }

    // Outcomes are buffered at settle so an off-tab foreground settle survives
    // until the toast mounts. Draining is FIFO and one-shot.
    func testSettleBuffersOutcomeDrainedExactlyOnce() async throws {
        let challengerUserId = "dev-duel-buffer-\(UUID().uuidString)"
        AuthService.shared.activateDevUser(id: challengerUserId)
        let challengerId = try XCTUnwrap(SquadUserIdentity.uuid(from: challengerUserId))
        let challengedId = try XCTUnwrap(SquadUserIdentity.uuid(from: "dev-duel-buffer-opp"))

        let service = FriendChallengeService(remoteBackendEnabled: true)
        let id = UUID()
        service._seedLocalChallengeForTesting(FriendChallenge(
            id: id,
            challengerId: challengerId,
            challengedId: challengedId,
            squadId: UUID(),
            kind: .mostSessions,
            exerciseName: nil,
            startedAt: .now.addingTimeInterval(-8 * 24 * 3600),
            expiresAt: .now.addingTimeInterval(-1),
            acceptedAt: .now.addingTimeInterval(-7 * 24 * 3600),
            challengerProgress: 5,
            challengedProgress: 2,
            winnerUserId: nil
        ))

        await service.evaluateExpired()

        let drained = service.consumePendingOutcome()
        XCTAssertEqual(drained?.id, id)
        XCTAssertEqual(drained?.winnerUserId, challengerId, "Settled outcome carries the winner")
        XCTAssertNil(service.consumePendingOutcome(), "Buffer is drained exactly once")
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
            exerciseName: nil,
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
