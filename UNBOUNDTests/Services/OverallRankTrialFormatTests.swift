import XCTest
@testable import UNBOUND

final class OverallRankTrialFormatTests: XCTestCase {
    func testLegacyRawValuesDecodeToNewFormats() throws {
        let legacyToNew: [String: RankTrialFormat] = [
            "daily100": .firstLight,
            "operatorScreen": .theCount,
            "finisher": .theForging,
            "fixedDeck": .deckOfProof,
            "tower": .theAscent,
            "bossRush": .sevenSeals,
            "raid": .theThreshold,
            "finalExam": .theLastGate
        ]
        for (legacy, expected) in legacyToNew {
            let data = Data("\"\(legacy)\"".utf8)
            let decoded = try JSONDecoder().decode(RankTrialFormat.self, from: data)
            XCTAssertEqual(decoded, expected, "legacy raw \(legacy)")
        }
    }

    func testDisplayNamesAreGateNames() {
        XCTAssertEqual(RankTrialFormat.firstLight.displayName, "First Light")
        XCTAssertEqual(RankTrialFormat.theCount.displayName, "The Count")
        XCTAssertEqual(RankTrialFormat.theForging.displayName, "The Forging")
        XCTAssertEqual(RankTrialFormat.deckOfProof.displayName, "The Reckoning")
        XCTAssertEqual(RankTrialFormat.theAscent.displayName, "The Ascent")
        XCTAssertEqual(RankTrialFormat.sevenSeals.displayName, "The Seven Seals")
        XCTAssertEqual(RankTrialFormat.theThreshold.displayName, "The Threshold")
        XCTAssertEqual(RankTrialFormat.theLastGate.displayName, "The Last Gate")
    }
}
