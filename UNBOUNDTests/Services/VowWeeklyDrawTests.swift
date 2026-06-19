import XCTest
@testable import UNBOUND

final class VowWeeklyDrawTests: XCTestCase {
    func testDrawsThreeCards() {
        let cards = VowWeeklyDraw.cards(weekNumber: 5, yearForWeekOfYear: 2026, completionsByLane: [:])
        XCTAssertEqual(cards.count, 3)
    }

    func testDeterministicForSameInputs() {
        let a = VowWeeklyDraw.cards(weekNumber: 5, yearForWeekOfYear: 2026, completionsByLane: [.recovery: 2])
        let b = VowWeeklyDraw.cards(weekNumber: 5, yearForWeekOfYear: 2026, completionsByLane: [.recovery: 2])
        XCTAssertEqual(a, b)
    }

    func testCardIdsCarryWeekStamp() {
        let cards = VowWeeklyDraw.cards(weekNumber: 7, yearForWeekOfYear: 2026, completionsByLane: [:])
        XCTAssertTrue(cards.allSatisfy { $0.id.contains("W7") })
    }

    func testCardIdsCarryYearStamp() {
        // The year must be in the id so the same ISO week number in a later year
        // does not collide and skip the OverallLevel XP grant.
        let cards = VowWeeklyDraw.cards(weekNumber: 7, yearForWeekOfYear: 2027, completionsByLane: [:])
        XCTAssertTrue(cards.allSatisfy { $0.id.contains("2027") })
    }

    func testNeglectedLaneIsRepresented() {
        // Recovery and engine are well-trodden; fuel neglected → fuel must appear.
        let cards = VowWeeklyDraw.cards(
            weekNumber: 3,
            yearForWeekOfYear: 2026,
            completionsByLane: [.recovery: 10, .engine: 10, .fuel: 0]
        )
        XCTAssertTrue(cards.contains { $0.lane == .fuel })
    }

    func testSpansMultipleLanes() {
        let cards = VowWeeklyDraw.cards(weekNumber: 1, yearForWeekOfYear: 2026, completionsByLane: [:])
        XCTAssertGreaterThanOrEqual(Set(cards.map(\.lane)).count, 2)
    }
}
