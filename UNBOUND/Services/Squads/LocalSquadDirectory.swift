import Foundation

final class LocalSquadDirectory {
    static let shared = LocalSquadDirectory()

    private struct Record: Codable, Equatable {
        var squad: Squad
        var members: [SquadMember]
    }

    private let defaults: UserDefaults
    private let key = "unbound.localSquadDirectory"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func squadForUser(_ userUUID: UUID) -> (squad: Squad, members: [SquadMember])? {
        records().values.first { record in
            record.members.contains { $0.userId == userUUID }
        }.map { ($0.squad, $0.members.sorted { $0.joinedAt < $1.joinedAt }) }
    }

    func createSquad(name: String, captainUUID: UUID, inviteCode: String) throws -> (squad: Squad, members: [SquadMember]) {
        var records = records()
        if records.values.contains(where: { record in
            record.members.contains { $0.userId == captainUUID }
        }) {
            throw SquadError.alreadyInSquad
        }
        guard records[inviteCode] == nil else {
            throw SquadError.backendUnavailable
        }

        let squadId = UUID()
        let now = Date()
        let squad = Squad(
            id: squadId,
            name: name,
            captainId: captainUUID,
            affinityAxis: nil,
            affinitySetAt: nil,
            inviteCode: inviteCode,
            maxSize: 8,
            squadStreakWeeks: 0,
            createdAt: now
        )
        let captain = SquadMember(
            id: UUID(),
            squadId: squadId,
            userId: captainUUID,
            joinedAt: now,
            displayName: "Captain",
            equippedTitle: nil,
            buildIdentity: nil
        )
        records[inviteCode] = Record(squad: squad, members: [captain])
        save(records)
        return (squad, [captain])
    }

    func adoptCachedSquad(_ squad: Squad, members: [SquadMember]) {
        var records = records()
        let normalizedCode = squad.inviteCode.uppercased()
        if var existing = records[normalizedCode] {
            let existingIds = Set(existing.members.map(\.userId))
            existing.members.append(contentsOf: members.filter { !existingIds.contains($0.userId) })
            existing.members.sort { $0.joinedAt < $1.joinedAt }
            records[normalizedCode] = existing
        } else {
            records[normalizedCode] = Record(squad: squad, members: members.sorted { $0.joinedAt < $1.joinedAt })
        }
        save(records)
    }

    func joinSquad(inviteCode: String, userUUID: UUID) throws -> (squad: Squad, members: [SquadMember]) {
        let normalizedCode = inviteCode.uppercased()
        var records = records()
        if records.values.contains(where: { record in
            record.members.contains { $0.userId == userUUID }
        }) {
            throw SquadError.alreadyInSquad
        }
        guard var record = records[normalizedCode] else {
            throw SquadError.invalidInviteCode
        }
        guard record.members.count < record.squad.maxSize else {
            throw SquadError.squadFull
        }

        let member = SquadMember(
            id: UUID(),
            squadId: record.squad.id,
            userId: userUUID,
            joinedAt: Date(),
            displayName: "Crewmate \(record.members.count + 1)",
            equippedTitle: nil,
            buildIdentity: nil
        )
        record.members.append(member)
        record.members.sort { $0.joinedAt < $1.joinedAt }
        records[normalizedCode] = record
        save(records)
        return (record.squad, record.members)
    }

    func leaveSquad(userUUID: UUID) throws -> (remainingState: SquadState?, removedSquadId: UUID) {
        var records = records()
        guard let pair = records.first(where: { _, record in
            record.members.contains { $0.userId == userUUID }
        }) else {
            throw SquadError.notInSquad
        }

        let code = pair.key
        var record = pair.value
        let removedSquadId = record.squad.id
        record.members.removeAll { $0.userId == userUUID }

        if record.members.isEmpty {
            records.removeValue(forKey: code)
            save(records)
            return (nil, removedSquadId)
        }

        if record.squad.captainId == userUUID, let newCaptain = record.members.first {
            record.squad = Squad(
                id: record.squad.id,
                name: record.squad.name,
                captainId: newCaptain.userId,
                affinityAxis: record.squad.affinityAxis,
                affinitySetAt: record.squad.affinitySetAt,
                inviteCode: record.squad.inviteCode,
                maxSize: record.squad.maxSize,
                squadStreakWeeks: record.squad.squadStreakWeeks,
                createdAt: record.squad.createdAt
            )
        }

        records[code] = record
        save(records)
        return (
            SquadState(
                currentSquad: record.squad,
                roster: record.members,
                activeRosterPresence: [],
                recentActivity: [],
                unlockedSquadTitles: []
            ),
            removedSquadId
        )
    }

    func updateAffinity(squadId: UUID, axis: AttributeKey?, setAt: Date?) {
        var records = records()
        guard let pair = records.first(where: { $0.value.squad.id == squadId }) else { return }
        var record = pair.value
        record.squad = Squad(
            id: record.squad.id,
            name: record.squad.name,
            captainId: record.squad.captainId,
            affinityAxis: axis,
            affinitySetAt: setAt,
            inviteCode: record.squad.inviteCode,
            maxSize: record.squad.maxSize,
            squadStreakWeeks: record.squad.squadStreakWeeks,
            createdAt: record.squad.createdAt
        )
        records[pair.key] = record
        save(records)
    }

    private func records() -> [String: Record] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Record].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    private func save(_ records: [String: Record]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }
}
