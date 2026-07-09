import XCTest
import UIKit
@testable import UNBOUND

enum TestProgressionDatabaseError: Error {
    case forcedCreateFailure(collection: String)
    case notFound(collection: String, documentId: String)
}

actor TestProgressionDatabase: DatabaseServiceProtocol {
    private var store: [String: [String: Any]] = [:]
    private var updateCallCounts: [String: Int] = [:]
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
        updateCallCounts[key, default: 0] += 1
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
        let prefix = "\(collection)/"
        var matches = store
            .filter { $0.key.hasPrefix(prefix) }
            .map(\.value)
            .filter { document in
                guard let stored = document[field] as? NSObject else { return false }
                return stored.isEqual(value)
            }
        if let orderBy {
            matches.sort { lhs, rhs in
                let ascending: Bool
                switch (lhs[orderBy], rhs[orderBy]) {
                case let (l as NSNumber, r as NSNumber):
                    ascending = l.compare(r) == .orderedAscending
                case let (l as String, r as String):
                    ascending = l < r
                default:
                    ascending = true
                }
                return descending ? !ascending : ascending
            }
        }
        let limited = limit.map { Array(matches.prefix($0)) } ?? matches
        return try limited.map { document in
            let data = try JSONSerialization.data(withJSONObject: document)
            return try JSONDecoder().decode(T.self, from: data)
        }
    }

    func countKeys(prefix: String) -> Int {
        store.keys.filter { $0.hasPrefix(prefix) }.count
    }

    /// Raw stored JSON dict, for asserting which keys a write actually
    /// serialized (e.g. that a snapshot omitted ledger fields).
    func rawDocument(collection: String, documentId: String) -> [String: Any]? {
        store[key(collection: collection, documentId: documentId)]
    }

    func updateCount(collection: String, documentId: String) -> Int {
        updateCallCounts[key(collection: collection, documentId: documentId)] ?? 0
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
    func consumePendingOutcome() -> FriendChallenge? { nil }
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
