import XCTest
@testable import UNBOUND

extension WeeklyVowsServiceTests {
    /// Build a v2 lane/bet/target card. Id is keyed on lane+bet so distinct
    /// lanes/bets produce distinct vow ids.
    func makeVowCard(
        lane: VowLane,
        bet: VowBet,
        target: VowTarget? = nil
    ) -> WeeklyVowCard {
        let resolvedTarget = target ?? VowTarget(count: 1, noun: "session")
        return WeeklyVowCard(
            id: "weekly-vow-test-\(lane.rawValue)-\(bet.rawValue)",
            lane: lane,
            bet: bet,
            displayName: "\(lane.displayLabel) · \(bet.displayLabel)",
            blurb: "A bound vow for \(lane.displayLabel.lowercased()).",
            target: resolvedTarget
        )
    }
}
