import Foundation

struct SquadMember: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let userId: UUID
    let joinedAt: Date
    // Joined fields, populated on roster fetch
    var displayName: String
    var equippedTitle: TitleID?
    var buildIdentity: BuildIdentity?
}
