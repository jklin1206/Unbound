// UNBOUND/Services/Squads/SquadBackend.swift
import Foundation
import Supabase

// MARK: - SquadBackend (production)
//
// Wraps UnboundSupabase.client for all squad-table operations.
// Tests never touch this file — they use MockSquadBackend.
//
// Row-struct convention (load-bearing): UnboundSupabase.dbDecoder uses
// .convertFromSnakeCase, so every Decodable row property MUST be camelCase —
// a snake_case property never matches the converted key and the whole decode
// throws keyNotFound. Encodable-only bodies sent through functions.invoke use
// snake_case because the Functions client encodes with a plain JSONEncoder.
// SquadBackendRowCodingTests locks this contract with real PostgREST fixtures.
//
final class SquadBackend: SquadBackendProtocol, @unchecked Sendable {

    static let shared = SquadBackend()
    private init() {}

    private var db: PostgrestClient { UnboundSupabase.client.schema("public") }

    // MARK: - SquadRow (internal Codable for Supabase mapping)

    private struct SquadRow: Codable {
        let id: UUID
        let name: String
        let captainId: UUID
        let affinityAxis: String?
        let affinitySetAt: Date?
        let inviteCode: String
        let maxSize: Int
        let squadStreakWeeks: Int
        let createdAt: Date
        let logoId: String?

        func toSquad() -> Squad {
            Squad(
                id: id,
                name: name,
                captainId: captainId,
                affinityAxis: affinityAxis.flatMap { AttributeKey(rawValue: $0) },
                affinitySetAt: affinitySetAt,
                inviteCode: inviteCode,
                maxSize: maxSize,
                squadStreakWeeks: squadStreakWeeks,
                createdAt: createdAt,
                logoId: logoId
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
        struct Insert: Encodable {
            let id: String
            let name: String
            let captainId: String
            let inviteCode: String
            let maxSize: Int
        }
        let body = Insert(
            id: id.uuidString,
            name: name,
            captainId: captainId.uuidString,
            inviteCode: inviteCode,
            maxSize: maxSize
        )
        do {
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
        } catch let error as PostgrestError where error.code == "23505" {
            // Unique violation — the generated invite code collided. Mapped to
            // a dedicated case so the service retries ONLY this failure.
            throw SquadError.inviteCodeCollision
        }
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

    func updateAffinity(squadId: UUID, axis: AttributeKey?, setAt: Date?) async throws {
        struct Patch: Encodable {
            let affinityAxis: String?
            let affinitySetAt: Date?
        }
        let patch = Patch(
            affinityAxis: axis?.rawValue,
            affinitySetAt: setAt
        )
        try await db
            .from("squads")
            .update(patch)
            .eq("id", value: squadId.uuidString)
            .execute()
    }

    func updateLogo(squadId: UUID, logoId: String) async throws {
        struct Patch: Encodable { let logoId: String }
        try await db
            .from("squads")
            .update(Patch(logoId: SquadLogoCatalog.resolvedId(logoId)))
            .eq("id", value: squadId.uuidString)
            .execute()
    }

    func updateName(squadId: UUID, name: String) async throws {
        struct Patch: Encodable { let name: String }
        try await db
            .from("squads")
            .update(Patch(name: name))
            .eq("id", value: squadId.uuidString)
            .execute()
    }

    func fetchMembers(squadId: UUID) async throws -> [SquadMember] {
        // Member names live in public.users, which is owner-only by RLS — a
        // co-member can't read them directly. The squad_members_enriched RPC
        // (SECURITY DEFINER, gated on is_squad_member) joins each member's
        // display name/handle in for fellow members. Equipped title and build
        // identity aren't stored cross-readably, so they stay nil for now.
        struct EnrichedRow: Decodable {
            let id: UUID
            let squadId: UUID
            let userId: UUID
            let joinedAt: Date
            let displayName: String?
            let displayHandle: String?
        }
        struct Params: Encodable { let pSquadId: String }
        let rows: [EnrichedRow] = try await UnboundSupabase.client
            .rpc("squad_members_enriched", params: Params(pSquadId: squadId.uuidString))
            .execute()
            .value
        return rows.map { row in
            SquadMember(
                id: row.id,
                squadId: row.squadId,
                userId: row.userId,
                joinedAt: row.joinedAt,
                displayName: Self.resolveDisplayName(
                    name: row.displayName,
                    handle: row.displayHandle,
                    userId: row.userId
                ),
                equippedTitle: nil,
                buildIdentity: nil
            )
        }
    }

    /// Real name → handle → a short, stable fallback. Never the raw UUID.
    private static func resolveDisplayName(name: String?, handle: String?, userId: UUID) -> String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let handle = handle?.trimmingCharacters(in: .whitespacesAndNewlines), !handle.isEmpty {
            return handle
        }
        return "Member \(userId.uuidString.prefix(4))"
    }

    func leaveSquad(squadId: UUID) async throws {
        // leave_squad_atomic handles captain succession (earliest-joined member
        // is promoted) and deletes the squad when the last member leaves —
        // client-side succession can't do either under RLS.
        struct Params: Encodable { let pSquadId: String }
        struct Result: Decodable {
            let error: String?
            let status: String?
        }
        let result: Result = try await UnboundSupabase.client
            .rpc("leave_squad_atomic", params: Params(pSquadId: squadId.uuidString))
            .execute()
            .value
        if let error = result.error {
            switch error {
            case "not_a_member", "squad_not_found": throw SquadError.notInSquad
            default: throw SquadError.backendUnavailable
            }
        }
    }

    func fetchMemberWorkoutLogs(
        squadId: UUID,
        since: Date,
        perMemberLimit: Int
    ) async throws -> [UUID: [WorkoutLog]] {
        // workout_logs is owner-only under RLS; this gated SECURITY DEFINER RPC
        // returns every squadmate's completed logs so streaks / workout days /
        // PRs on the board are computed from real data — by the same Swift
        // code (SquadLeaderboardBuilder) that scores the local user.
        struct Params: Encodable {
            let pSquadId: String
            let pSince: Date
            let pPerMemberLimit: Int
        }
        // Typed mirror of a workout_logs row: WorkoutLog itself can't decode a
        // server row (overall_rpe converts to `overallRpe`, not `overallRPE`,
        // and program_id is nullable server-side but "" locally).
        struct RemoteWorkoutLog: Decodable {
            let id: UUID
            let userId: UUID
            let programId: UUID?
            let dayNumber: Int
            let plannedWorkoutName: String
            let startedAt: Date
            let completedAt: Date?
            let durationMinutes: Int?
            let overallRpe: Int?
            let overallNotes: String?
            let localStartHour: Int?
            let exerciseEntries: [ExerciseLogEntry]

            func toModel() -> WorkoutLog {
                WorkoutLog(
                    id: id.uuidString,
                    userId: userId.uuidString,
                    programId: programId?.uuidString ?? "",
                    dayNumber: dayNumber,
                    plannedWorkoutName: plannedWorkoutName,
                    startedAt: startedAt,
                    completedAt: completedAt,
                    exerciseEntries: exerciseEntries,
                    overallNotes: overallNotes,
                    overallRPE: overallRpe,
                    durationMinutes: durationMinutes,
                    localStartHour: localStartHour
                )
            }
        }
        struct LogRow: Decodable {
            let memberUserId: UUID
            let log: RemoteWorkoutLog
        }
        let rows: [LogRow] = try await UnboundSupabase.client
            .rpc(
                "squad_member_workout_logs",
                params: Params(
                    pSquadId: squadId.uuidString,
                    pSince: since,
                    pPerMemberLimit: perMemberLimit
                )
            )
            .execute()
            .value

        var logsByMember: [UUID: [WorkoutLog]] = [:]
        for row in rows {
            logsByMember[row.memberUserId, default: []].append(row.log.toModel())
        }
        return logsByMember
    }

    func invokeJoinSquadEdgeFunction(inviteCode: String, userId: UUID) async throws -> Squad {
        struct JoinBody: Encodable {
            // Functions bodies encode with a plain JSONEncoder — keep snake_case.
            let invite_code: String
        }
        struct JoinResponse: Decodable {
            let squad: SquadRow
        }
        let body = JoinBody(invite_code: inviteCode.uppercased())
        let options = FunctionInvokeOptions(body: body)
        do {
            // The response decodes squad-table timestamps + snake_case keys, so
            // it needs dbDecoder — the Functions client's default JSONDecoder
            // can't parse ISO dates and would throw on every successful join.
            let response: JoinResponse = try await UnboundSupabase.client.functions
                .invoke("join_squad", options: options, decoder: UnboundSupabase.dbDecoder)
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
        struct MemberIdRow: Codable { let squadId: UUID }
        let rows: [MemberIdRow] = try await db
            .from("squad_members")
            .select("squad_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.squadId
    }

    func incrementMissionProgress(squadId: UUID, delta: Int, sourceLogId: String) async throws {
        struct IncrementParams: Encodable, Sendable {
            let pSquadId: String
            let pDelta: Int
            let pSourceLogId: String
        }
        try await UnboundSupabase.client
            .rpc(
                "increment_squad_mission_progress",
                params: IncrementParams(
                    pSquadId: squadId.uuidString,
                    pDelta: delta,
                    pSourceLogId: sourceLogId
                )
            )
            .execute()
    }

    func fetchMissionContributions(missionId: UUID) async throws -> [MissionContribution] {
        struct ReceiptRow: Decodable {
            let userId: UUID?
            let delta: Int
        }
        let rows: [ReceiptRow] = try await db
            .from("squad_mission_progress_receipts")
            .select("user_id, delta")
            .eq("mission_id", value: missionId.uuidString)
            .execute()
            .value
        return MissionContribution.aggregate(rows: rows.map { ($0.userId, $0.delta) })
    }

    func pickSquadMission(squadId: UUID, kind: SquadMission.Kind) async throws -> SquadMission? {
        struct PickParams: Encodable, Sendable {
            let pSquadId: String
            let pKind: String
        }
        // MissionRow mirrors the service's private struct — replicated here for RPC decode.
        struct MissionRow: Decodable {
            let id: UUID
            let squadId: UUID
            let weekIso: String
            let missionKind: String
            let target: Int
            let currentProgress: Int
            let completedAt: Date?
            let createdAt: Date

            func toModel() -> SquadMission? {
                guard let k = SquadMission.Kind(rawValue: missionKind) else { return nil }
                return SquadMission(
                    id: id,
                    squadId: squadId,
                    weekIso: weekIso,
                    kind: k,
                    target: target,
                    currentProgress: currentProgress,
                    completedAt: completedAt,
                    createdAt: createdAt
                )
            }
        }
        let rows: [MissionRow] = try await UnboundSupabase.client
            .rpc(
                "pick_squad_mission",
                params: PickParams(pSquadId: squadId.uuidString, pKind: kind.rawValue)
            )
            .execute()
            .value
        return rows.first?.toModel()
    }

    func fetchCompletedMissionCount(squadId: UUID, since: Date, until: Date) async throws -> Int {
        struct CountRow: Decodable { let id: UUID }
        let rows: [CountRow] = try await db
            .from("squad_missions")
            .select("id")
            .eq("squad_id", value: squadId.uuidString)
            .not("completed_at", operator: .is, value: "null")
            .gte("completed_at", value: ISO8601DateFormatter().string(from: since))
            .lt("completed_at", value: ISO8601DateFormatter().string(from: until))
            .execute()
            .value
        return rows.count
    }

    func fetchRecentLinkedSessions(squadId: UUID, limit: Int) async throws -> [LinkedSession] {
        struct LinkedSessionRow: Codable {
            let id: UUID
            let squadId: UUID
            let userIds: [UUID]
            let startedAt: Date
            let endedAt: Date
        }
        let rows: [LinkedSessionRow] = try await db
            .from("linked_sessions")
            .select("id, squad_id, user_ids, started_at, ended_at")
            .eq("squad_id", value: squadId.uuidString)
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.map {
            LinkedSession(
                id: $0.id,
                squadId: $0.squadId,
                userIds: $0.userIds,
                startedAt: $0.startedAt,
                endedAt: $0.endedAt
            )
        }
    }
}
