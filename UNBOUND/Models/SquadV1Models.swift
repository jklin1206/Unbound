import Foundation

enum SquadBadgeTier: Int, Codable, Comparable, Sendable {
    case none = 0
    case one = 1
    case two = 2
    case three = 3

    static func < (lhs: SquadBadgeTier, rhs: SquadBadgeTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var roman: String {
        switch self {
        case .none: return "-"
        case .one: return "I"
        case .two: return "II"
        case .three: return "III"
        }
    }
}

struct AccountabilityBadgeState: Codable, Equatable, Sendable {
    let userId: UUID
    var clearedCount: Int

    var currentTier: SquadBadgeTier {
        switch clearedCount {
        case 25...: return .three
        case 5...: return .two
        case 1...: return .one
        default: return .none
        }
    }

    var nextTierTarget: Int? {
        switch clearedCount {
        case ..<1: return 1
        case ..<5: return 5
        case ..<25: return 25
        default: return nil
        }
    }

    var progressToNextTier: Double {
        guard let target = nextTierTarget else { return 1 }
        return min(1, Double(clearedCount) / Double(target))
    }
}

struct CrewStreakBadgeState: Codable, Equatable, Sendable {
    let squadId: UUID
    var consecutiveWeeks: Int
    var weekIsoLast: String?

    var currentTier: SquadBadgeTier {
        switch consecutiveWeeks {
        case 26...: return .three
        case 12...: return .two
        case 5...: return .one
        default: return .none
        }
    }

    var nextTierTarget: Int? {
        switch consecutiveWeeks {
        case ..<5: return 5
        case ..<12: return 12
        case ..<26: return 26
        default: return nil
        }
    }

    var progressToNextTier: Double {
        guard let target = nextTierTarget else { return 1 }
        return min(1, Double(consecutiveWeeks) / Double(target))
    }
}

struct SquadMessageReaction: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let messageId: UUID
    let userId: UUID
    let emoji: Emoji
    let createdAt: Date

    enum Emoji: String, Codable, CaseIterable, Sendable {
        case fire = "🔥"
        case flex = "💪"
        case clap = "👏"
        case heart = "❤️"
        case eyes = "👀"
    }
}

struct SquadMessage: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let authorUserId: UUID?
    var kind: Kind
    var reactions: [SquadMessageReaction]
    let createdAt: Date

    enum Kind: Codable, Equatable, Sendable {
        case text(TextPayload)
        case workout(WorkoutPayload)
        case pr(PRPayload)
        case vowSeal(VowSealPayload)
        case challengeEvent(ChallengeEventPayload)
        case savedWorkoutShare(SavedWorkoutSharePayload)
        case system(SystemPayload)
    }

    struct TextPayload: Codable, Equatable, Sendable {
        let body: String
    }

    struct WorkoutPayload: Codable, Equatable, Sendable {
        let title: String
        let durationMinutes: Int?
    }

    struct PRPayload: Codable, Equatable, Sendable {
        let title: String
        let detail: String
    }

    struct VowSealPayload: Codable, Equatable, Sendable {
        let title: String
    }

    struct ChallengeEventPayload: Codable, Equatable, Sendable {
        let title: String
        let detail: String
        let challengeId: UUID?
    }

    struct SavedWorkoutSharePayload: Codable, Equatable, Sendable {
        let shareId: UUID
        let workoutTitle: String
        let sharedById: UUID
    }

    struct SystemPayload: Codable, Equatable, Sendable {
        let body: String
    }
}

struct OpenChallenge: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let creatorId: UUID
    var title: String
    var dueAt: Date?
    let createdAt: Date
    var status: Status
    var joiners: [OpenChallengeJoiner]

    enum Status: String, Codable, Sendable {
        case open
        case declared
        case canceled
    }
}

struct OpenChallengeJoiner: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let challengeId: UUID
    let userId: UUID
    var score: Double?
    var submittedAt: Date?
}

struct CoopPairChallenge: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let creatorId: UUID
    let partnerId: UUID
    var targetSessions: Int
    let windowStart: Date
    let windowEnd: Date
    var status: Status
    var creatorProgress: Int
    var partnerProgress: Int

    enum Status: String, Codable, Sendable {
        case pending
        case active
        case cleared
        case missed
        case declined
    }
}

struct SavedWorkoutShare: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let savedWorkoutId: UUID
    let sharedById: UUID
    let sharedAt: Date
}
