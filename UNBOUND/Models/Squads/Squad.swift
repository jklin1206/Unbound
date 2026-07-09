import Foundation

struct Squad: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let captainId: UUID
    let affinityAxis: AttributeKey?
    let affinitySetAt: Date?
    let inviteCode: String
    let maxSize: Int
    let squadStreakWeeks: Int
    let createdAt: Date
    let logoId: String?

    init(
        id: UUID,
        name: String,
        captainId: UUID,
        affinityAxis: AttributeKey?,
        affinitySetAt: Date?,
        inviteCode: String,
        maxSize: Int,
        squadStreakWeeks: Int,
        createdAt: Date,
        logoId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.captainId = captainId
        self.affinityAxis = affinityAxis
        self.affinitySetAt = affinitySetAt
        self.inviteCode = inviteCode
        self.maxSize = maxSize
        self.squadStreakWeeks = squadStreakWeeks
        self.createdAt = createdAt
        self.logoId = logoId
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case captainId
        case affinityAxis
        case affinitySetAt
        case inviteCode
        case maxSize
        case squadStreakWeeks
        case createdAt
        case logoId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        captainId = try container.decode(UUID.self, forKey: .captainId)
        affinityAxis = try container.decodeIfPresent(AttributeKey.self, forKey: .affinityAxis)
        affinitySetAt = try container.decodeIfPresent(Date.self, forKey: .affinitySetAt)
        inviteCode = try container.decode(String.self, forKey: .inviteCode)
        maxSize = try container.decode(Int.self, forKey: .maxSize)
        squadStreakWeeks = try container.decode(Int.self, forKey: .squadStreakWeeks)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        logoId = try container.decodeIfPresent(String.self, forKey: .logoId)
    }
}

// MARK: - Invite URL

extension Squad {
    /// Inviteable URL — used by Share Sheet flows.
    var inviteURL: URL? {
        URL(string: "https://unboundbtr.com/squad/\(inviteCode)")
    }

    func replacingCaptain(_ captainId: UUID) -> Squad {
        Squad(
            id: id,
            name: name,
            captainId: captainId,
            affinityAxis: affinityAxis,
            affinitySetAt: affinitySetAt,
            inviteCode: inviteCode,
            maxSize: maxSize,
            squadStreakWeeks: squadStreakWeeks,
            createdAt: createdAt,
            logoId: logoId
        )
    }

    func replacingAffinity(axis: AttributeKey?, setAt: Date?) -> Squad {
        Squad(
            id: id,
            name: name,
            captainId: captainId,
            affinityAxis: axis,
            affinitySetAt: setAt,
            inviteCode: inviteCode,
            maxSize: maxSize,
            squadStreakWeeks: squadStreakWeeks,
            createdAt: createdAt,
            logoId: logoId
        )
    }

    func replacingStreakWeeks(_ weeks: Int) -> Squad {
        Squad(
            id: id,
            name: name,
            captainId: captainId,
            affinityAxis: affinityAxis,
            affinitySetAt: affinitySetAt,
            inviteCode: inviteCode,
            maxSize: maxSize,
            squadStreakWeeks: max(0, weeks),
            createdAt: createdAt,
            logoId: logoId
        )
    }

    func replacingLogo(_ logoId: String) -> Squad {
        Squad(
            id: id,
            name: name,
            captainId: captainId,
            affinityAxis: affinityAxis,
            affinitySetAt: affinitySetAt,
            inviteCode: inviteCode,
            maxSize: maxSize,
            squadStreakWeeks: squadStreakWeeks,
            createdAt: createdAt,
            logoId: SquadLogoCatalog.resolvedId(logoId)
        )
    }

    func replacingName(_ name: String) -> Squad {
        Squad(
            id: id,
            name: name,
            captainId: captainId,
            affinityAxis: affinityAxis,
            affinitySetAt: affinitySetAt,
            inviteCode: inviteCode,
            maxSize: maxSize,
            squadStreakWeeks: squadStreakWeeks,
            createdAt: createdAt,
            logoId: logoId
        )
    }

    var resolvedLogoId: String {
        SquadLogoCatalog.resolvedId(logoId)
    }
}
