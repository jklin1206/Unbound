import XCTest
@testable import UNBOUND

final class VowWeeklyDrawTests: XCTestCase {
    func testDrawsThreeCards() {
        let cards = VowWeeklyDraw.cards(weekNumber: 5, completionsByLane: [:])
        XCTAssertEqual(cards.count, 3)
    }

    func testDeterministicForSameInputs() {
        let a = VowWeeklyDraw.cards(weekNumber: 5, completionsByLane: [.recovery: 2])
        let b = VowWeeklyDraw.cards(weekNumber: 5, completionsByLane: [.recovery: 2])
        XCTAssertEqual(a, b)
    }

    func testCardIdsCarryWeekStamp() {
        let cards = VowWeeklyDraw.cards(weekNumber: 7, completionsByLane: [:])
        XCTAssertTrue(cards.allSatisfy { $0.id.contains("W7") })
    }

    func testNeglectedLaneIsRepresented() {
        // Recovery and engine are well-trodden; fuel neglected → fuel must appear.
        let cards = VowWeeklyDraw.cards(
            weekNumber: 3,
            completionsByLane: [.recovery: 10, .engine: 10, .fuel: 0]
        )
        XCTAssertTrue(cards.contains { $0.lane == .fuel })
    }

    func testSpansMultipleLanes() {
        let cards = VowWeeklyDraw.cards(weekNumber: 1, completionsByLane: [:])
        XCTAssertGreaterThanOrEqual(Set(cards.map(\.lane)).count, 2)
    }
}
