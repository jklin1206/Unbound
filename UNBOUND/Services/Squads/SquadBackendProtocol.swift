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

    // MARK: Mission progress

    /// Increment the current ISO-week mission's `current_progress` for a squad
    /// by `delta`. RLS blocks direct client UPDATE on squad_missions (update
    /// policy `using (false)`), so this routes through the SECURITY DEFINER
    /// `increment_squad_mission_progress` RPC, which guards on squad membership.
    func incrementMissionProgress(squadId: UUID, delta: Int) async throws

    // MARK: Linked sessions

    /// Fetch the most recent `linked_sessions` rows for a squad (newest first).
    /// Rows are inserted server-side by the `detect_linked_sessions` Edge
    /// Function. The client recovers which ones it has not yet processed via a
    /// persisted processed-id set (the table carries no per-user processed flag).
    func fetchRecentLinkedSessions(squadId: UUID, limit: Int) async throws -> [LinkedSession]
}

// MARK: - LinkedSession
//
// Client mirror of a `linked_sessions` row. NOTE: the table carries only
// id / squad_id / user_ids / started_at / ended_at — there is NO workout-log
// id and NO base-XP column, so base session XP cannot be recovered FROM this
// row. The reconciler recovers it from the local SessionXPService instead.
struct LinkedSession: Identifiable, Sendable, Equatable {
    let id: UUID
    let squadId: UUID
    let userIds: [UUID]
    let startedAt: Date
    let endedAt: Date
}
