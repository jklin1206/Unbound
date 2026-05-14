import Foundation

@MainActor
protocol FriendChallengeServiceProtocol: Sendable {
    func createChallenge(challengedId: UUID, kind: FriendChallenge.Kind, squadId: UUID) async throws -> FriendChallenge
    func activeChallenges(userId: UUID) async -> [FriendChallenge]
    func accept(_ challengeId: UUID) async throws
    func recordProgress(log: WorkoutLog, userId: String) async
    func evaluateExpired() async
}

@MainActor
final class FriendChallengeService: FriendChallengeServiceProtocol {
    static let shared = FriendChallengeService()
    private let backend: SquadBackendProtocol
    private let logger = LoggingService.shared

    init(backend: SquadBackendProtocol = SquadBackend.shared) {
        self.backend = backend
    }

    func createChallenge(challengedId: UUID, kind: FriendChallenge.Kind, squadId: UUID) async throws -> FriendChallenge {
        // TODO(squads-impl): backend.createFriendChallenge(...)
        throw SquadError.backendUnavailable
    }

    func activeChallenges(userId: UUID) async -> [FriendChallenge] {
        // TODO(squads-impl): backend.fetchActiveChallenges(userId:)
        return []
    }

    func accept(_ challengeId: UUID) async throws {
        // TODO(squads-impl): backend.updateChallengeAccepted(id:)
    }

    func recordProgress(log: WorkoutLog, userId: String) async {
        // For each active challenge involving userId, increment progress
        // based on challenge.kind. TODO real impl.
    }

    func evaluateExpired() async {
        // For each expired-but-no-winner challenge, compute winner by metric,
        // mark winner, post .friendChallengeExpired notification.
    }
}
