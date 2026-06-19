import Foundation

struct SquadPresence: Codable, Identifiable, Equatable, Sendable {
    let userId: UUID
    let squadId: UUID
    let workoutStartedAt: Date
    let expiresAt: Date

    var id: UUID { userId }
    var isActive: Bool { Date.now < expiresAt }
}
