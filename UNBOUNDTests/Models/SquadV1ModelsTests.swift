import XCTest
@testable import UNBOUND

final class SquadV1ModelsTests: XCTestCase {
    func testAccountabilityBadgeTierThresholds() {
        let userId = UUID()
        XCTAssertEqual(AccountabilityBadgeState(userId: userId, clearedCount: 0).currentTier, .none)
        XCTAssertEqual(AccountabilityBadgeState(userId: userId, clearedCount: 1).currentTier, .one)
        XCTAssertEqual(AccountabilityBadgeState(userId: userId, clearedCount: 5).currentTier, .two)
        XCTAssertEqual(AccountabilityBadgeState(userId: userId, clearedCount: 25).currentTier, .three)
    }

    func testCrewStreakBadgeTierThresholds() {
        let squadId = UUID()
        XCTAssertEqual(CrewStreakBadgeState(squadId: squadId, consecutiveWeeks: 4, weekIsoLast: nil).currentTier, .none)
        XCTAssertEqual(CrewStreakBadgeState(squadId: squadId, consecutiveWeeks: 5, weekIsoLast: nil).currentTier, .one)
        XCTAssertEqual(CrewStreakBadgeState(squadId: squadId, consecutiveWeeks: 12, weekIsoLast: nil).currentTier, .two)
        XCTAssertEqual(CrewStreakBadgeState(squadId: squadId, consecutiveWeeks: 26, weekIsoLast: nil).currentTier, .three)
    }

    func testSquadMessageRoundtrip() throws {
        let message = SquadMessage(
            id: UUID(),
            squadId: UUID(),
            authorUserId: UUID(),
            kind: .challengeEvent(.init(title: "Pushups in 60s", detail: "Sam submitted 44", challengeId: UUID())),
            reactions: [
                SquadMessageReaction(
                    id: UUID(),
                    messageId: UUID(),
                    userId: UUID(),
                    emoji: .fire,
                    createdAt: Date()
                )
            ],
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(SquadMessage.self, from: data)
        XCTAssertEqual(decoded, message)
    }
}
