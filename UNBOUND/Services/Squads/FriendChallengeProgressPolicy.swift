import Foundation

enum FriendChallengeProgressPolicy {
    /// Client-side qualifying signal. The server computes the real weighted delta
    /// from the trusted workout log (Task E2); this +1 only tells the backend the
    /// log qualifies. `earlyRiser` keeps its before-8am gate so non-qualifying
    /// logs never even send the signal.
    static func progressDelta(
        for kind: FriendChallenge.Kind,
        log: WorkoutLog,
        calendar: Calendar = .current
    ) -> Int {
        switch kind {
        case .earlyRiser:
            let hour = log.localStartHour ?? calendar.component(.hour, from: log.startedAt)
            return (0..<8).contains(hour) ? 1 : 0
        case .mostSessions, .mostWeight, .mostReps, .heaviestLift:
            return 1
        }
    }
}
