import XCTest
import UIKit
@testable import UNBOUND

final class CrossingAssetResolverTests: XCTestCase {

    func test_fallsBackToRankBannerWhenNoBespokeArt() {
        // Plan 3: no gate_threshold_* assets shipped yet → resolver returns the rank banner.
        for c in GateCrossingCatalog.all {
            let still = CrossingAssetResolver.thresholdStill(for: c)
            XCTAssertEqual(still, c.world.bannerAssetName,
                           "\(c.id) should fall back to the rank banner until bespoke art lands")
            XCTAssertNotNil(UIImage(named: still), "fallback banner \(still) must exist in the catalog")
            XCTAssertFalse(CrossingAssetResolver.hasBespokeArt(for: c))
        }
    }

    func test_bespokeNameFollowsRankToken() {
        let forge = GateCrossingCatalog.crossing(for: .theForging)
        XCTAssertEqual(CrossingAssetResolver.bespokeStillName(for: forge), "gate_threshold_forged")
    }
}
