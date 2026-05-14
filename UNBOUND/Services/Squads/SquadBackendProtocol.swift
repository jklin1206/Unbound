// UNBOUND/Services/Squads/SquadBackendProtocol.swift
import Foundation

// MARK: - SquadBackendProtocol
//
// Thin abstraction over the Supabase squad-table operations.
// Production: SquadBackend wraps UnboundSupabase.client.
// Tests:       MockSquadBackend uses in-memory dictionaries + call tracking.
//
// SquadService depends on this protocol instead of reaching into
// SupabaseClient or DatabaseServiceProtocol directly, which keeps
// squad-table unit tests fast and hermetic.

protocol SquadBackendProtocol: Sendable {

    // MARK: Squad CRUD

    /// Insert a new squad row. Returns the persisted Squad.
    func insertSquad(
        id: UUID,
        name: String,
        captainId: UUID,
        inviteCode: String,
        maxSize: Int
    ) async throws -> Squad

    /// Fetch a squad by primary key. Throws if not found.
    func fetchSquad(byId squadId: UUID) async throws -> Squad

    /// Fetch a squad by its invite code. Returns nil if not found.
    func fetchSquadByInviteCode(_ code: String) async throws -> Squad?

    /// Delete a squad row (cascade clears members + activity + presence).
    func deleteSquad(squadId: UUID) async throws

    /// Update the captain_id column for a squad.
    func updateCaptain(squadId: UUID, newCaptainId: UUID) async throws

    /// Update the affinity_axis + affinity_set_at columns for a squad.
    func updateAffinity(squadId: UUID, axis: AttributeKey?, setAt: Date?) async throws

    // MARK: Member operations

    /// Return all members for a squad, ordered by joined_at ascending.
    func fetchMembers(squadId: UUID) async throws -> [SquadMember]

    /// Remove a single member row.
    func deleteMember(squadId: UUID, userId: UUID) async throws

    // MARK: Edge Function

    /// Invoke the `join_squad` Edge Function which:
    ///   - validates the invite code
    ///   - checks squad max_size
    ///   - inserts the squad_members row
    ///   - posts a memberJoined activity (server-side)
    ///   - returns the joined Squad row
    ///
    /// Throws SquadError for known failure modes so the service can
    /// re-surface them to the call site without string parsing.
    func invokeJoinSquadEdgeFunction(inviteCode: String, userId: UUID) async throws -> Squad

    // MARK: Membership query

    /// Return the squadId the given user belongs to, or nil if none.
    func fetchMySquadId(userId: UUID) async throws -> UUID?
}
