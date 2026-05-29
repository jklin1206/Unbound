// UNBOUND/Services/Squads/SquadBackend.swift
import Foundation
import Supabase

// MARK: - SquadBackend (production)
//
// Wraps UnboundSupabase.client for all squad-table operations.
// Tests never touch this file — they use MockSquadBackend.
//
// NOTE: supabase-swift SDK table-query semantics are confirmed from
// the existing codebase usage (SupabaseClient.swift, AuthService.swift).
// The table operations below use the standard `.from(_:).select()` /
// `.insert(_:)` / `.update(_:)` / `.delete()` query-builder pattern.
// TODO(squads-impl): confirm exact column name casing with the live migration
// before merging to main. RLS policies must be applied via CLI before the
// production impl runs end-to-end.

final class SquadBackend: SquadBackendProtocol, @unchecked Sendable {

    static let shared = SquadBackend()
    private init() {}

    private var db: PostgrestClient { UnboundSupabase.client.schema("public") }

    // MARK: - SquadRow (internal Codable for Supabase mapping)

    private struct SquadRow: Codable {
        let id: UUID
        let name: String
        let captain_id: UUID  // snake_case matches Supabase column
        let affinity_axis: String?
        let affinity_set_at: Date?
        let invite_code: String
        let max_size: Int
        let squad_streak_weeks: Int
        let created_at: Date

        func toSquad() -> Squad {
            Squad(
                id: id,
                name: name,
                captainId: captain_id,
                affinityAxis: affinity_axis.flatMap { AttributeKey(rawValue: $0) },
                affinitySetAt: affinity_set_at,
                inviteCode: invite_code,
                maxSize: max_size,
                squadStreakWeeks: squad_streak_weeks,
                createdAt: created_at
            )
        }
    }

    private struct MemberRow: Codable {
        let id: UUID
        let squad_id: UUID
        let user_id: UUID
        let joined_at: Date

        func toMember() -> SquadMember {
            SquadMember(
                id: id,
                squadId: squad_id,
                userId: user_id,
                joinedAt: joined_at,
                displayName: user_id.uuidString,   // enrichment deferred
                equippedTitle: nil,
                buildIdentity: nil
            )
        }
    }

    // MARK: - SquadBackendProtocol

    func insertSquad(
        id: UUID,
        name: String,
        captainId: UUID,
        inviteCode: String,
        maxSize: Int
    ) async throws -> Squad {
        // TODO(squads-impl): wire concrete Supabase insert once SDK confirmed
        struct Insert: Encodable {
            let id: String
            let name: String
            let captain_id: String
            let invite_code: String
            let max_size: Int
        }
        let body = Insert(
            id: id.uuidString,
            name: name,
            captain_id: captainId.uuidString,
            invite_code: inviteCode,
            max_size: maxSize
        )
        let rows: [SquadRow] = try await db
            .from("squads")
            .insert(body)
            .select()
            .execute()
            .value
        guard let row = rows.first else {
            throw SquadError.backendUnavailable
        }
        return row.toSquad()
    }

    func fetchSquad(byId squadId: UUID) async throws -> Squad {
        let rows: [SquadRow] = try await db
            .from("squads")
            .select()
            .eq("id", value: squadId.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else {
            throw SquadError.backendUnavailable
        }
        return row.toSquad()
    }

    func fetchSquadByInviteCode(_ code: String) async throws -> Squad? {
        let rows: [SquadRow] = try await db
            .from("squads")
            .select()
            .eq("invite_code", value: code)
            .limit(1)
            .execute()
            .value
        return rows.first?.toSquad()
    }

    func deleteSquad(squadId: UUID) async throws {
        try await db
            .from("squads")
            .delete()
            .eq("id", value: squadId.uuidString)
            .execute()
    }

    func updateCaptain(squadId: UUID, newCaptainId: UUID) async throws {
        struct Patch: Encodable { let captain_id: String }
        try await db
            .from("squads")
            .update(Patch(captain_id: newCaptainId.uuidString))
            .eq("id", value: squadId.uuidString)
            .execute()
    }

    func updateAffinity(squadId: UUID, axis: AttributeKey?, setAt: Date?) async throws {
        struct Patch: Encodable {
            let affinity_axis: String?
            let affinity_set_at: Date?
        }
        let patch = Patch(
            affinity_axis: axis?.rawValue,
            affinity_set_at: setAt
        )
        try await db
            .from("squads")
            .update(patch)
            .eq("id", value: squadId.uuidString)
            .execute()
    }

    func fetchMembers(squadId: UUID) async throws -> [SquadMember] {
        let rows: [MemberRow] = try await db
            .from("squad_members")
            .select()
            .eq("squad_id", value: squadId.uuidString)
            .order("joined_at", ascending: true)
            .execute()
            .value
        return rows.map { $0.toMember() }
    }

    func deleteMember(squadId: UUID, userId: UUID) async throws {
        try await db
            .from("squad_members")
            .delete()
            .eq("squad_id", value: squadId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func invokeJoinSquadEdgeFunction(inviteCode: String, userId: UUID) async throws -> Squad {
        struct JoinBody: Encodable {
            let invite_code: String
        }
        struct JoinResponse: Decodable {
            let squad: SquadRow
        }
        let body = JoinBody(invite_code: inviteCode.uppercased())
        let options = FunctionInvokeOptions(body: body)
        do {
            let response: JoinResponse = try await UnboundSupabase.client.functions
                .invoke("join_squad", options: options)
            return response.squad.toSquad()
        } catch let error as FunctionsError {
            switch error {
            case .httpError(_, let data):
                // Surface structured error codes from the Edge Function
                if let payload = try? JSONDecoder().decode([String: String].self, from: data) {
                    switch payload["error"] {
                    case "already_in_squad": throw SquadError.alreadyInSquad
                    case "squad_full":       throw SquadError.squadFull
                    case "invalid_invite_code": throw SquadError.invalidInviteCode
                    default: break
                    }
                }
                throw SquadError.backendUnavailable
            case .relayError:
                throw SquadError.backendUnavailable
            }
        }
    }

    func fetchMySquadId(userId: UUID) async throws -> UUID? {
        struct MemberIdRow: Codable { let squad_id: UUID }
        let rows: [MemberIdRow] = try await db
            .from("squad_members")
            .select("squad_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.squad_id
    }

    func incrementMissionProgress(squadId: UUID, delta: Int) async throws {
        struct IncrementParams: Encodable, Sendable {
            let p_squad_id: String
            let p_delta: Int
        }
        try await UnboundSupabase.client
            .rpc(
                "increment_squad_mission_progress",
                params: IncrementParams(p_squad_id: squadId.uuidString, p_delta: delta)
            )
            .execute()
    }
}
