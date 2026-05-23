import Foundation

struct SquadState: Codable, Equatable, Sendable {
    var currentSquad: Squad?
    var roster: [SquadMember]
    var activeRosterPresence: [SquadPresence]
    var recentActivity: [SquadActivityEntry]  // capped at 50
    var unlockedSquadTitles: [SquadTitleID]

    static let empty = SquadState(
        currentSquad: nil,
        roster: [],
        activeRosterPresence: [],
        recentActivity: [],
        unlockedSquadTitles: []
    )
}
