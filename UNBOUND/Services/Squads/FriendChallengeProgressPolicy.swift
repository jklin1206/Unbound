import Foundation

enum FriendChallengeProgressPolicy {
    static func progressDelta(
        for kind: FriendChallenge.Kind,
        log: WorkoutLog,
        calendar: Calendar = .current
    ) -> Int {
        switch kind {
        case .mostSessions:
            return 1
        case .earlyRiser:
            let hour = log.localStartHour ?? calendar.component(.hour, from: log.startedAt)
            return (0..<8).contains(hour) ? 1 : 0
        case .noMissedDays,
             .firstToFinishTrial,
             .mostAlignedSessions,
             .proteinGoal:
            return 0
        }
    }

    static func unsupportedReason(for kind: FriendChallenge.Kind) -> String? {
        switch kind {
        case .mostSessions,
             .earlyRiser:
            return nil
        case .noMissedDays:
            return "requires full streak recomputation from workout history"
        case .firstToFinishTrial:
            return "requires trial completion events"
        case .mostAlignedSessions:
            return "requires workout axis metadata"
        case .proteinGoal:
            return "requires nutrition tracking"
        }
    }
}
