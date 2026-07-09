// UNBOUND/Services/Squads/MockSquadBackend.swift
#if DEBUG
import Foundation

// MARK: - MockSquadBackend
//
// In-memory test double for SquadBackendProtocol.
// Tests control behaviour by:
//   • pre-seeding `squads` / `members` dictionaries
//   • setting `throwOnInviteCode` to map specific codes to errors
//   • reading `captainUpdates`, `deletedSquads`, etc. for assertion

final class MockSquadBackend: SquadBackendProtocol, @unchecked Sendable {

    // MARK: In-memory state

    var squads: [UUID: Squad] = [:]
    var members: [UUID: [SquadMember]] = [:]   // squadId → members

    /// The auth identity `leaveSquad` acts as — the real RPC resolves
    /// auth.uid() server-side, so tests set this before calling leave.
    var currentAuthUserId: UUID?

    // MARK: Call log (for assertion in tests)

    var insertedSquads: [Squad] = []
    var leaveCalls: [UUID] = []
    var deletedSquads: [UUID] = []
    var captainPromotions: [(squadId: UUID, newCaptainId: UUID)] = []
    var affinityUpdates: [(squadId: UUID, axis: AttributeKey?, setAt: Date?)] = []
    var logoUpdates: [(squadId: UUID, logoId: String)] = []
    var nameUpdates: [(squadId: UUID, name: String)] = []
    var missionProgressIncrements: [(squadId: UUID, delta: Int, sourceLogId: String)] = []

    // MARK: Error injection

    /// Map an invite code string to the error it should throw.
    var throwOnInviteCode: [String: SquadError] = [:]

    /// If set, `insertSquad` throws this error (simulates invite-code collision).
    var insertSquadError: Error? = nil

    // MARK: - SquadBackendProtocol

    func insertSquad(
        id: UUID,
        name: String,
        captainId: UUID,
        inviteCode: String,
        maxSize: Int
    ) async throws -> Squad {
        if let err = insertSquadError { throw err }
        let squad = Squad(
            id: id,
            name: name,
            captainId: captainId,
            affinityAxis: nil,
            affinitySetAt: nil,
            inviteCode: inviteCode,
            maxSize: maxSize,
            squadStreakWeeks: 0,
            createdAt: Date(),
            logoId: SquadLogoCatalog.defaultId
        )
        squads[id] = squad
        // Server trigger auto-joins captain as first member.
        let captainMember = SquadMember(
            id: UUID(),
            squadId: id,
            userId: captainId,
            joinedAt: Date(),
            displayName: captainId.uuidString,
            equippedTitle: nil,
            buildIdentity: nil
        )
        members[id] = [captainMember]
        insertedSquads.append(squad)
        return squad
    }

    func fetchSquad(byId squadId: UUID) async throws -> Squad {
        guard let squad = squads[squadId] else {
            throw SquadError.backendUnavailable
        }
        return squad
    }

    func fetchSquadByInviteCode(_ code: String) async throws -> Squad? {
        squads.values.first { $0.inviteCode == code }
    }

    func updateAffinity(squadId: UUID, axis: AttributeKey?, setAt: Date?) async throws {
        guard let existing = squads[squadId] else { throw SquadError.backendUnavailable }
        squads[squadId] = existing.replacingAffinity(axis: axis, setAt: setAt)
        affinityUpdates.append((squadId: squadId, axis: axis, setAt: setAt))
    }

    func updateLogo(squadId: UUID, logoId: String) async throws {
        guard let existing = squads[squadId] else { throw SquadError.backendUnavailable }
        let resolved = SquadLogoCatalog.resolvedId(logoId)
        squads[squadId] = existing.replacingLogo(resolved)
        logoUpdates.append((squadId: squadId, logoId: resolved))
    }

    func updateName(squadId: UUID, name: String) async throws {
        guard let existing = squads[squadId] else { throw SquadError.backendUnavailable }
        squads[squadId] = existing.replacingName(name)
        nameUpdates.append((squadId: squadId, name: name))
    }

    func fetchMembers(squadId: UUID) async throws -> [SquadMember] {
        (members[squadId] ?? []).sorted { $0.joinedAt < $1.joinedAt }
    }

    /// Mirrors leave_squad_atomic: removes the caller's membership, promotes
    /// the earliest-joined remaining member if the captain left, deletes the
    /// squad when nobody remains.
    func leaveSquad(squadId: UUID) async throws {
        guard let userId = currentAuthUserId else { throw SquadError.notInSquad }
        guard let squad = squads[squadId] else { throw SquadError.notInSquad }
        guard (members[squadId] ?? []).contains(where: { $0.userId == userId }) else {
            throw SquadError.notInSquad
        }
        leaveCalls.append(squadId)
        members[squadId]?.removeAll { $0.userId == userId }

        guard squad.captainId == userId else { return }
        let remaining = (members[squadId] ?? []).sorted { $0.joinedAt < $1.joinedAt }
        if let successor = remaining.first {
            squads[squadId] = squad.replacingCaptain(successor.userId)
            captainPromotions.append((squadId: squadId, newCaptainId: successor.userId))
        } else {
            squads.removeValue(forKey: squadId)
            members.removeValue(forKey: squadId)
            deletedSquads.append(squadId)
        }
    }

    var memberWorkoutLogs: [UUID: [WorkoutLog]] = [:]   // memberUserId → logs

    func fetchMemberWorkoutLogs(
        squadId: UUID,
        since: Date,
        perMemberLimit: Int
    ) async throws -> [UUID: [WorkoutLog]] {
        memberWorkoutLogs.mapValues { logs in
            Array(
                logs
                    .filter { ($0.completedAt ?? $0.startedAt) >= since }
                    .sorted { ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt) }
                    .prefix(perMemberLimit)
            )
        }
    }

    func invokeJoinSquadEdgeFunction(inviteCode: String, userId: UUID) async throws -> Squad {
        if let err = throwOnInviteCode[inviteCode] { throw err }
        guard let squad = try await fetchSquadByInviteCode(inviteCode) else {
            throw SquadError.invalidInviteCode
        }
        let currentCount = (members[squad.id] ?? []).count
        if currentCount >= squad.maxSize {
            throw SquadError.squadFull
        }
        let alreadyIn = (members[squad.id] ?? []).contains { $0.userId == userId }
        if alreadyIn { throw SquadError.alreadyInSquad }
        // Insert member row.
        let newMember = SquadMember(
            id: UUID(),
            squadId: squad.id,
            userId: userId,
            joinedAt: Date(),
            displayName: userId.uuidString,
            equippedTitle: nil,
            buildIdentity: nil
        )
        members[squad.id, default: []].append(newMember)
        return squad
    }

    func fetchMySquadId(userId: UUID) async throws -> UUID? {
        members.first { _, roster in roster.contains { $0.userId == userId } }?.key
    }

    func incrementMissionProgress(squadId: UUID, delta: Int, sourceLogId: String) async throws {
        missionProgressIncrements.append((squadId: squadId, delta: delta, sourceLogId: sourceLogId))
    }

    var contributionsToReturn: [MissionContribution] = []
    func fetchMissionContributions(missionId: UUID) async throws -> [MissionContribution] {
        return contributionsToReturn
    }

    var pickSquadMissionResult: SquadMission? = nil
    func pickSquadMission(squadId: UUID, kind: SquadMission.Kind) async throws -> SquadMission? {
        return pickSquadMissionResult
    }

    var completedMissionCount: Int = 0
    func fetchCompletedMissionCount(squadId: UUID, since: Date, until: Date) async throws -> Int {
        return completedMissionCount
    }

    var linkedSessions: [UUID: [LinkedSession]] = [:]   // squadId → rows

    func fetchRecentLinkedSessions(squadId: UUID, limit: Int) async throws -> [LinkedSession] {
        Array((linkedSessions[squadId] ?? []).sorted { $0.startedAt > $1.startedAt }.prefix(limit))
    }
}
#endif
