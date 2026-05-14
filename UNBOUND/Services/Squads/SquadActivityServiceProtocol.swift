// UNBOUND/Services/Squads/SquadActivityServiceProtocol.swift
import Foundation

@MainActor
protocol SquadActivityServiceProtocol: AnyObject {
    /// Record an activity entry for the user's current squad.
    /// No-op if the user is not in a squad.
    func record(kind: SquadActivityEntry.Kind, payload: SquadActivityPayload, userId: String) async

    /// Fetch the 50 most-recent activity entries for the user's squad.
    /// Returns [] if the user is not in a squad.
    func fetchRecent(userId: String) async throws -> [SquadActivityEntry]
}
