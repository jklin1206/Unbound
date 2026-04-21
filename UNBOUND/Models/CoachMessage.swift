import Foundation

enum CoachRole: String, Codable { case user, assistant, system }

struct CoachMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: String
    let role: CoachRole
    var content: String
    var appliedActions: [CoachAction]
    let timestamp: Date

    init(
        id: UUID = UUID(),
        userId: String,
        role: CoachRole,
        content: String,
        appliedActions: [CoachAction] = [],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.role = role
        self.content = content
        self.appliedActions = appliedActions
        self.timestamp = timestamp
    }
}
