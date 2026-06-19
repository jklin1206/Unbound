import Foundation

// MARK: - MissionContribution
//
// Aggregated receipt total per member for a completed or in-progress mission.
// `userId` is nil for train_together receipts (source_log_id "linked:…", no auth user).
struct MissionContribution: Codable, Equatable, Sendable {
    let userId: UUID?
    let total: Int

    /// Aggregate raw (userId, delta) receipt rows into per-user contribution totals.
    static func aggregate(rows: [(userId: UUID?, delta: Int)]) -> [MissionContribution] {
        var totals: [UUID?: Int] = [:]
        for row in rows {
            totals[row.userId, default: 0] += row.delta
        }
        return totals.map { MissionContribution(userId: $0.key, total: $0.value) }
            .sorted { ($0.total, $0.userId?.uuidString ?? "") > ($1.total, $1.userId?.uuidString ?? "") }
    }
}

struct SquadMission: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let squadId: UUID
    let weekIso: String     // "2026-W20"
    let kind: Kind
    let target: Int
    var currentProgress: Int
    var completedAt: Date?
    let createdAt: Date

    var isCompleted: Bool { completedAt != nil }
    var progressFraction: Double { Double(currentProgress) / Double(max(target, 1)) }

    enum Kind: String, Codable, CaseIterable, Sendable {
        case totalWeight = "total_weight"
        case totalSessions = "total_sessions"
        case totalReps = "total_reps"
        case crewCoverage = "crew_coverage"
        case trainTogether = "train_together"

        init?(rawValue: String) {
            switch rawValue {
            case "total_weight": self = .totalWeight
            case "total_sessions", "alignedSessions", "focusSessions",
                 "capstonesTogether", "tierCrossings": self = .totalSessions
            case "total_reps": self = .totalReps
            case "crew_coverage", "perfectAttendance": self = .crewCoverage
            case "train_together", "linkedSessions": self = .trainTogether
            default: return nil
            }
        }

        var displayName: String {
            switch self {
            case .totalWeight: return "Iron Mountain"
            case .totalSessions: return "Session Stack"
            case .totalReps: return "Rep Avalanche"
            case .crewCoverage: return "Full Crew"
            case .trainTogether: return "Linked Up"
            }
        }

        var subtitle: String {
            switch self {
            case .totalWeight: return "Move this much combined weight as a crew."
            case .totalSessions: return "Stack combined sessions this week."
            case .totalReps: return "Combined reps, every set counts."
            case .crewCoverage: return "Every member trains 3+ times."
            case .trainTogether: return "Train at the same time as a squadmate."
            }
        }

        var systemImage: String {
            switch self {
            case .totalWeight: return "scalemass.fill"
            case .totalSessions: return "calendar.badge.checkmark"
            case .totalReps: return "repeat"
            case .crewCoverage: return "person.3.fill"
            case .trainTogether: return "link"
            }
        }

        func progressText(_ value: Int) -> String {
            let formatted = value.formatted(.number)
            switch self {
            case .totalWeight: return "\(formatted) kg"
            case .totalSessions: return value == 1 ? "1 session" : "\(formatted) sessions"
            case .totalReps: return "\(formatted) reps"
            case .crewCoverage: return "\(formatted) covered"
            case .trainTogether: return value == 1 ? "1 linked" : "\(formatted) linked"
            }
        }
    }
}
