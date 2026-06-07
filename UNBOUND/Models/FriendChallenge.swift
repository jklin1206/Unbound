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

        static let creationOptions: [Kind] = [
            .mostSessions,
            .earlyRiser
        ]

        var isSupportedForCreation: Bool {
            Self.creationOptions.contains(self)
        }

        var displayName: String {
            switch self {
            case .mostSessions: return "Most Sessions"
            case .noMissedDays: return "No Missed Days"
            case .firstToFinishTrial: return "First Challenge Clear"
            case .mostAlignedSessions: return "Most Aligned"
            case .earlyRiser: return "Early Riser (8am)"
            case .proteinGoal: return "Protein Goal"
            }
        }

        var subtitle: String {
            switch self {
            case .mostSessions: return "Most workout sessions this week."
            case .noMissedDays: return "Longest consecutive day streak."
            case .firstToFinishTrial: return "First to clear the weekly test."
            case .mostAlignedSessions: return "Most aligned-axis sessions."
            case .earlyRiser: return "Most workouts before 8 AM."
            case .proteinGoal: return "Most days hitting protein target."
            }
        }

        var systemImage: String {
            switch self {
            case .mostSessions: return "calendar.badge.checkmark"
            case .noMissedDays: return "flame.fill"
            case .firstToFinishTrial: return "flag.checkered"
            case .mostAlignedSessions: return "scope"
            case .earlyRiser: return "sunrise.fill"
            case .proteinGoal: return "fork.knife"
            }
        }

        func progressLabel(for value: Int) -> String {
            let noun = value == 1 ? "session" : "sessions"
            return "\(value) \(noun)"
        }
    }
}

struct FriendChallengeStats: Codable, Equatable, Sendable {
    var wins: Int
    var seasonWins: Int
    var activeCount: Int
    var pendingCount: Int

    init(wins: Int, seasonWins: Int = 0, activeCount: Int, pendingCount: Int) {
        self.wins = wins
        self.seasonWins = seasonWins
        self.activeCount = activeCount
        self.pendingCount = pendingCount
    }

    static let empty = FriendChallengeStats(wins: 0, seasonWins: 0, activeCount: 0, pendingCount: 0)
}
