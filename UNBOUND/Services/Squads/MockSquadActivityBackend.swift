// UNBOUND/Services/Squads/MockSquadActivityBackend.swift
import Foundation

// In-memory mock for SquadActivityBackendProtocol.
// Used in SquadActivityServiceTests. Kept in main target under #if DEBUG
// so tests (which link the main target) can reach it without a separate test helper target.

#if DEBUG
final class MockSquadActivityBackend: SquadActivityBackendProtocol, @unchecked Sendable {
    var insertedEntries: [SquadActivityEntry] = []
    var stubbedFetchResult: [SquadActivityEntry] = []
    var fetchError: Error? = nil

    func insert(_ entry: SquadActivityEntry) async {
        insertedEntries.append(entry)
    }

    func fetchRecent(squadId: UUID, limit: Int) async throws -> [SquadActivityEntry] {
        if let error = fetchError { throw error }
        return stubbedFetchResult
    }
}
#endif
