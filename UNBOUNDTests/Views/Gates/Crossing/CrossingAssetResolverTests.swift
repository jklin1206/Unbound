import XCTest
import UIKit
@testable import UNBOUND

final class CrossingAssetResolverTests: XCTestCase {

    func test_resolvesToBespokeThresholdArtForEveryGate() {
        // Plan 3: bespoke gate_threshold_<token> art now ships for all 8 gates.
        for c in GateCrossingCatalog.all {
            let still = CrossingAssetResolver.thresholdStill(for: c)
            XCTAssertEqual(still, CrossingAssetResolver.bespokeStillName(for: c),
                           "\(c.id) should resolve to its bespoke threshold still")
            XCTAssertNotNil(UIImage(named: still), "threshold still \(still) must exist in the catalog")
            XCTAssertTrue(CrossingAssetResolver.hasBespokeArt(for: c))
        }
    }

    func test_bespokeNameFollowsRankToken() {
        let forge = GateCrossingCatalog.crossing(for: .theForging)
        XCTAssertEqual(CrossingAssetResolver.bespokeStillName(for: forge), "gate_threshold_forged")
    }
}
