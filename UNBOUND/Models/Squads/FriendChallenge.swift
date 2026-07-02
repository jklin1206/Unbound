import Foundation

struct FriendChallenge: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let challengerId: UUID
    let challengedId: UUID
    let squadId: UUID
    let kind: Kind
    /// Set only for `heaviestLift` (the catalog display name the lift is scoped
    /// to). Nil for every other kind.
    let exerciseName: String?
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
        case earlyRiser
        case mostWeight
        case mostReps
        case heaviestLift

        static let creationOptions: [Kind] = Kind.allCases
        var isSupportedForCreation: Bool { true }

        /// Heaviest Lift is scoped to one exercise chosen at creation.
        var requiresExercisePick: Bool { self == .heaviestLift }

        /// MAX-semantics kinds show a best-so-far score, not a running total.
        var usesMaxScore: Bool { self == .heaviestLift }

        var displayName: String {
            switch self {
            case .mostSessions: return "Most Sessions"
            case .earlyRiser: return "Early Riser (8am)"
            case .mostWeight: return "Most Weight"
            case .mostReps: return "Most Reps"
            case .heaviestLift: return "Heaviest Lift"
            }
        }

        var subtitle: String {
            switch self {
            case .mostSessions: return "Most workout sessions this week."
            case .earlyRiser: return "Most workouts before 8 AM."
            case .mostWeight: return "Most combined \(WeightPlatePolicy.currentUnit.shortLabel) moved this week."
            case .mostReps: return "Most combined reps this week."
            case .heaviestLift: return "Pick a lift. Heaviest single set wins."
            }
        }

        var systemImage: String {
            switch self {
            case .mostSessions: return "calendar.badge.checkmark"
            case .earlyRiser: return "sunrise.fill"
            case .mostWeight: return "scalemass.fill"
            case .mostReps: return "repeat"
            case .heaviestLift: return "trophy.fill"
            }
        }

        /// Weight scores are stored in kilograms; convert to the user's unit
        /// for display.
        func progressLabel(
            for value: Int,
            unit: TrainingWeightUnit = WeightPlatePolicy.currentUnit
        ) -> String {
            switch self {
            case .mostSessions, .earlyRiser:
                return value == 1 ? "1 session" : "\(value.formatted(.number)) sessions"
            case .mostWeight, .heaviestLift:
                let display = Int(unit.displayValue(fromKilograms: Double(value)).rounded())
                return "\(display.formatted(.number)) \(unit.shortLabel)"
            case .mostReps: return "\(value.formatted(.number)) reps"
            }
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
