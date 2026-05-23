// UNBOUND/Services/Squads/SquadActivityBackendProtocol.swift
import Foundation

// Thin abstraction over the two Supabase calls needed by SquadActivityService.
// Tests inject MockSquadActivityBackend; production uses SquadActivityBackend.

protocol SquadActivityBackendProtocol: Sendable {
    /// Insert a single activity entry into squad_activity.
    func insert(_ entry: SquadActivityEntry) async

    /// Fetch the most-recent `limit` activity entries for a squad, ordered by createdAt DESC.
    func fetchRecent(squadId: UUID, limit: Int) async throws -> [SquadActivityEntry]
}
