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
}

// MARK: - Invite URL

extension Squad {
    /// Inviteable URL — used by Share Sheet flows.
    var inviteURL: URL? {
        URL(string: "https://unboundapp.com/squad/\(inviteCode)")
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
            createdAt: createdAt
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
            createdAt: createdAt
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
            createdAt: createdAt
        )
    }
}
