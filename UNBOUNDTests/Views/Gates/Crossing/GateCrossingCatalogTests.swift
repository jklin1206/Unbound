import XCTest
@testable import UNBOUND

final class GateCrossingCatalogTests: XCTestCase {

    func test_everyFormatHasACrossing() {
        for format in RankTrialFormat.allCases {
            let c = GateCrossingCatalog.crossing(for: format)
            XCTAssertEqual(c.id, format)
            XCTAssertFalse(c.dwellLine.isEmpty, "\(format) missing dwell line")
        }
        XCTAssertEqual(GateCrossingCatalog.all.count, 8)
    }

    func test_tierLaddersWithGateOrder() {
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .firstLight).tier, .short)
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .deckOfProof).tier, .short)   // order 4
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .theAscent).tier, .full)      // order 5
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .theThreshold).tier, .full)   // order 7
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .theLastGate).tier, .finale)  // order 8
    }

    func test_investitureTitleIsDestinationRank() {
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .theForging).investitureTitle, "FORGED.")
        XCTAssertEqual(GateCrossingCatalog.crossing(for: .theLastGate).investitureTitle, "UNBOUND.")
    }

    func test_copyIsBrandSafe() {
        let banned = ["limiter", "weak link", "holding you back", "emom", "amrap", "wod", "metcon"]
        for c in GateCrossingCatalog.all {
            let lower = (c.dwellLine + " " + c.unlockChip + " " + c.investitureTitle).lowercased()
            for word in banned {
                XCTAssertFalse(lower.contains(word), "\(c.id) copy contains banned term '\(word)'")
            }
        }
    }
}
