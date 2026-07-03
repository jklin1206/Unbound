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

struct SquadRoutineDrop: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let authorUserId: UUID
    let authorDisplayName: String
    let title: String
    let note: String?
    let workout: SavedWorkout
    let createdAt: Date

    init(
        id: UUID = UUID(),
        squadId: UUID,
        authorUserId: UUID,
        authorDisplayName: String,
        title: String,
        note: String?,
        workout: SavedWorkout,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.squadId = squadId
        self.authorUserId = authorUserId
        self.authorDisplayName = Self.cleaned(authorDisplayName, fallback: "Crewmate", limit: 42)
        self.title = Self.cleaned(title, fallback: workout.title.isEmpty ? "Shared Workout" : workout.title, limit: 72)
        self.note = Self.cleanedOptional(note, limit: 180)
        self.workout = workout
        self.createdAt = createdAt
    }

    var exerciseCount: Int { workout.exerciseCount }
    var estimatedMinutes: Int { workout.estimatedMinutes }

    func savedWorkoutCopy(now: Date = Date()) -> SavedWorkout {
        let suffix = authorDisplayName == "You" ? "Squad Drop" : "From \(authorDisplayName)"
        var copy = workout
        copy.id = UUID()
        copy.title = "\(title) - \(suffix)"
        copy.order = 0
        copy.createdAt = now
        copy.updatedAt = now
        return copy
    }

    private static func cleaned(_ value: String, fallback: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(limit))
    }

    private static func cleanedOptional(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(limit))
    }
}
