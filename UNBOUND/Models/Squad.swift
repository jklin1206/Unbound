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
}
