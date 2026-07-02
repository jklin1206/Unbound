import XCTest
import UIKit
@testable import UNBOUND

final class ScanContextUserService: UserServiceProtocol, @unchecked Sendable {
    func createUserIfNeeded(userId: String, email: String?) async throws -> UserProfile {
        profile(userId: userId)
    }

    func fetchProfile(userId: String) async throws -> UserProfile {
        profile(userId: userId)
    }

    func updateProfile(userId: String, fields: [String: Any]) async throws {}

    func deleteUserData(userId: String) async throws {}

    private func profile(userId: String) -> UserProfile {
        UserProfile(
            id: userId,
            email: nil,
            displayName: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            onboardingCompleted: true,
            totalScans: 0
        )
    }
}

enum TestProgressionDatabaseError: Error {
    case forcedCreateFailure(collection: String)
    case notFound(collection: String, documentId: String)
}

actor TestProgressionDatabase: DatabaseServiceProtocol {
    private var store: [String: [String: Any]] = [:]
    private let delayMissingCompletionRecordReads: Bool
    private let failingCreateCollections: Set<String>
    private var failingCreateAttempts: [String: Int]

    init(
        delayMissingCompletionRecordReads: Bool = false,
        failingCreateCollections: Set<String> = [],
        failingCreateAttempts: [String: Int] = [:]
    ) {
        self.delayMissingCompletionRecordReads = delayMissingCompletionRecordReads
        self.failingCreateCollections = failingCreateCollections
        self.failingCreateAttempts = failingCreateAttempts
    }

    func create<T: Codable>(_ object: T, collection: String, documentId: String) async throws {
        if failingCreateCollections.contains(collection) {
            throw TestProgressionDatabaseError.forcedCreateFailure(collection: collection)
        }
        if let remaining = failingCreateAttempts[collection], remaining > 0 {
            failingCreateAttempts[collection] = remaining - 1
            throw TestProgressionDatabaseError.forcedCreateFailure(collection: collection)
        }
        let data = try JSONEncoder().encode(object)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        store[key(collection: collection, documentId: documentId)] = dict
    }

    func read<T: Codable>(collection: String, documentId: String) async throws -> T {
        let key = key(collection: collection, documentId: documentId)
        if delayMissingCompletionRecordReads,
           collection == "training_completion_records",
           store[key] == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard let dict = store[key] else {
            throw TestProgressionDatabaseError.notFound(collection: collection, documentId: documentId)
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func update(_ fields: [String: Any], collection: String, documentId: String) async throws {
        let key = key(collection: collection, documentId: documentId)
        var existing = store[key] ?? [:]
        for (field, value) in fields {
            existing[field] = value
        }
        store[key] = existing
    }

    func delete(collection: String, documentId: String) async throws {
        store.removeValue(forKey: key(collection: collection, documentId: documentId))
    }

    func query<T: Codable>(
        collection: String,
        field: String,
        isEqualTo value: Any,
        orderBy: String?,
        descending: Bool,
        limit: Int?
    ) async throws -> [T] {
        []
    }

    func countKeys(prefix: String) -> Int {
        store.keys.filter { $0.hasPrefix(prefix) }.count
    }

    private func key(collection: String, documentId: String) -> String {
        "\(collection)/\(documentId)"
    }
}

@MainActor
final class NoOpSquadMissionService: SquadMissionServiceProtocol {
    func generateThisWeek(squadId: UUID) async throws -> SquadMission { throw SquadError.backendUnavailable }
    func currentMission(squadId: UUID) async -> SquadMission? { nil }
    func latestMission(squadId: UUID) async -> SquadMission? { nil }
    func recordProgress(log: WorkoutLog, userId: String, sourceLogId: String) async {}
    func evaluateCompletion(squadId: UUID) async {}
    func pickMission(squadId: UUID, kind: SquadMission.Kind) async throws -> SquadMission? { nil }
    func fetchMissionContributions(missionId: UUID) async throws -> [MissionContribution] { [] }
}

@MainActor
final class NoOpFriendChallengeService: FriendChallengeServiceProtocol {
    func createChallenge(challengedId: UUID, kind: FriendChallenge.Kind, squadId: UUID, exerciseName: String?) async throws -> FriendChallenge {
        throw SquadError.backendUnavailable
    }
    func activeChallenges(userId: UUID) async -> [FriendChallenge] { [] }
    func challengeStats(squadId: UUID) async -> [UUID: FriendChallengeStats] { [:] }
    func accept(_ challengeId: UUID) async throws {}
    func decline(_ challengeId: UUID) async throws {}
    func recordProgress(log: WorkoutLog, userId: String, sourceLogId: String) async {}
    func evaluateExpired() async {}
}

/// A WorkoutLogServiceProtocol impl that deliberately does NOT conform to
/// WorkoutLogCompatibilityHistoryWriting, so completion must quarantine
/// compatible history to a direct database write instead of routing through
/// this service.
final class NonCompatibilityWriterWorkoutLogService: WorkoutLogServiceProtocol, @unchecked Sendable {
    var logs: [WorkoutLog] = []

    func updateLog(_ log: WorkoutLog) async throws {
        logs.removeAll { $0.id == log.id }
        logs.append(log)
    }

    func fetchLogs(userId: String, programId: String?) async throws -> [WorkoutLog] {
        if let programId { return logs.filter { $0.programId == programId } }
        return logs
    }

    func fetchRecentLogs(userId: String, limit: Int) async throws -> [WorkoutLog] {
        Array(logs.prefix(limit))
    }

    func deleteLog(id: String) async throws {
        logs.removeAll { $0.id == id }
    }
}
