import Foundation

struct FriendChallenge: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let challengerId: UUID
    let challengedId: UUID
    let squadId: UUID
    let kind: Kind
    let startedAt: Date
    let expiresAt: Date
    var acceptedAt: Date?
    var challengerProgress: Int
    var challengedProgress: Int
    var winnerUserId: UUID?

    var isActive: Bool { winnerUserId == nil && Date() < expiresAt }
    var isExpired: Bool { Date() >= expiresAt }
    var isPending: Bool { acceptedAt == nil }

    enum Kind: String, Codable, CaseIterable, Sendable {
        case mostSessions
        case noMissedDays
        case firstToFinishTrial
        case mostAlignedSessions
        case earlyRiser
        case proteinGoal

        var displayName: String {
            switch self {
            case .mostSessions: return "Most Sessions"
            case .noMissedDays: return "No Missed Days"
            case .firstToFinishTrial: return "First Binding Vow"
            case .mostAlignedSessions: return "Most Aligned"
            case .earlyRiser: return "Early Riser (8am)"
            case .proteinGoal: return "Protein Goal"
            }
        }

        var subtitle: String {
            switch self {
            case .mostSessions: return "Most workout sessions this week."
            case .noMissedDays: return "Longest consecutive day streak."
            case .firstToFinishTrial: return "First to clear a Binding Vow."
            case .mostAlignedSessions: return "Most aligned-axis sessions."
            case .earlyRiser: return "Most workouts before 8 AM."
            case .proteinGoal: return "Most days hitting protein target."
            }
        }
    }
}
