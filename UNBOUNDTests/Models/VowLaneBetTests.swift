import XCTest
@testable import UNBOUND

final class VowLaneBetTests: XCTestCase {
    func testBetEconomicsMatchSpec() {
        XCTAssertEqual(VowBet.small.oweXP, 150)
        XCTAssertEqual(VowBet.small.winXP, 50)
        XCTAssertEqual(VowBet.medium.oweXP, 250)
        XCTAssertEqual(VowBet.medium.winXP, 100)
        XCTAssertEqual(VowBet.large.oweXP, 300)
        XCTAssertEqual(VowBet.large.winXP, 150)
    }

    func testCodableRoundTrips() throws {
        for lane in VowLane.allCases {
            let data = try JSONEncoder().encode(lane)
            XCTAssertEqual(try JSONDecoder().decode(VowLane.self, from: data), lane)
        }
        for bet in VowBet.allCases {
            let data = try JSONEncoder().encode(bet)
            XCTAssertEqual(try JSONDecoder().decode(VowBet.self, from: data), bet)
        }
    }

    func testTargetDisplayText() {
        XCTAssertEqual(VowTarget(count: 1, noun: "recovery reset").displayText, "1 recovery reset")
        XCTAssertEqual(VowTarget(count: 3, noun: "fuel anchor").displayText, "3 fuel anchors")
    }
}
