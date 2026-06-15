import XCTest
import SwiftUI
import UIKit
@testable import UNBOUND

final class GateWorldCatalogTests: XCTestCase {
    func testEveryFormatResolvesToAWorld() {
        for format in RankTrialFormat.allCases {
            let world = GateWorldCatalog.world(for: format)
            XCTAssertEqual(world.format, format)
            XCTAssertFalse(world.promise.isEmpty, "promise for \(format)")
            XCTAssertFalse(world.numeral.isEmpty, "numeral for \(format)")
        }
    }

    func testNumeralsAreRomanOneThroughEight() {
        let expected = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
        let numerals = RankTrialFormat.allCases.map { GateWorldCatalog.world(for: $0).numeral }
        XCTAssertEqual(numerals, expected)
    }

    func testDestinationRankMatchesTheGateLadder() {
        XCTAssertEqual(GateWorldCatalog.world(for: .firstLight).destinationRank, .novice)
        XCTAssertEqual(GateWorldCatalog.world(for: .theForging).destinationRank, .forged)
        XCTAssertEqual(GateWorldCatalog.world(for: .theLastGate).destinationRank, .unbound)
    }

    func testBannerAssetsAllExistInTheBundle() {
        for format in RankTrialFormat.allCases {
            let name = GateWorldCatalog.world(for: format).bannerAssetName
            XCTAssertNotNil(UIImage(named: name), "missing banner asset \(name)")
        }
    }

    func testDifficultyPipsAreMonotonicByGateOrder() {
        let pips = RankTrialFormat.allCases.map { GateWorldCatalog.world(for: $0).difficultyPips }
        XCTAssertEqual(pips, [1, 2, 3, 4, 5, 6, 7, 8])
    }
}
