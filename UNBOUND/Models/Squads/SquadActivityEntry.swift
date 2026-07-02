import Foundation

struct SquadActivityEntry: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case workoutCompleted
        case trialCompleted
        case titleUnlocked
        case linkedSession
        case memberJoined
        case affinityChanged
        case squadStreakExtended
    }

    let id: UUID
    let squadId: UUID
    let userId: UUID?
    let kind: Kind
    let payload: SquadActivityPayload
    let createdAt: Date
}

enum SquadActivityPayload: Codable, Equatable, Sendable {
    case workoutCompleted(title: String, exerciseCount: Int, durationMinutes: Int?)
    case trialCompleted(trialName: String, theme: TrialTheme)
    case titleUnlocked(titleId: TitleID)
    case linkedSession(participantUserIds: [UUID], durationMinutes: Int)
    case memberJoined(memberDisplayName: String)
    case affinityChanged(newAxis: AttributeKey?, byDisplayName: String)
    case squadStreakExtended(weeks: Int)
}
