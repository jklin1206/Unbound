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

    // MARK: Call log (for assertion in tests)

    var insertedSquads: [Squad] = []
    var captainUpdates: [(squadId: UUID, newCaptainId: UUID)] = []
    var deletedSquads: [UUID] = []
    var deletedMembers: [(squadId: UUID, userId: UUID)] = []
    var affinityUpdates: [(squadId: UUID, axis: AttributeKey?, setAt: Date?)] = []
    var logoUpdates: [(squadId: UUID, logoId: String)] = []
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

    func deleteSquad(squadId: UUID) async throws {
        squads.removeValue(forKey: squadId)
        members.removeValue(forKey: squadId)
        deletedSquads.append(squadId)
    }

    func updateCaptain(squadId: UUID, newCaptainId: UUID) async throws {
        guard let existing = squads[squadId] else { throw SquadError.backendUnavailable }
        squads[squadId] = existing.replacingCaptain(newCaptainId)
        captainUpdates.append((squadId: squadId, newCaptainId: newCaptainId))
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

    func fetchMembers(squadId: UUID) async throws -> [SquadMember] {
        (members[squadId] ?? []).sorted { $0.joinedAt < $1.joinedAt }
    }

    func deleteMember(squadId: UUID, userId: UUID) async throws {
        members[squadId]?.removeAll { $0.userId == userId }
        deletedMembers.append((squadId: squadId, userId: userId))
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
