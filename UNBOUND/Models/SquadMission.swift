import Foundation

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
        case alignedSessions   // X aligned-axis sessions across the squad
        case capstonesTogether // X Binding Vow completions across the squad
        case focusSessions     // X focus-mode sessions across the squad
        case tierCrossings     // X tier crossings across the squad
        case linkedSessions    // X linked sessions across the squad
        case perfectAttendance // every member trains 4+ times

        var displayName: String {
            switch self {
            case .alignedSessions: return "Aligned Crew"
            case .capstonesTogether: return "Proof Crew"
            case .focusSessions: return "Focus Crew"
            case .tierCrossings: return "Tier Crossing"
            case .linkedSessions: return "Linked Crew"
            case .perfectAttendance: return "Perfect Attendance"
            }
        }

        var subtitle: String {
            switch self {
            case .alignedSessions: return "Hit aligned-axis sessions together."
            case .capstonesTogether: return "Each clear a Binding Vow."
            case .focusSessions: return "Hit focus-mode sessions as a crew."
            case .tierCrossings: return "Cross tiers together."
            case .linkedSessions: return "Stack linked workouts."
            case .perfectAttendance: return "All in, all week."
            }
        }
    }
}
