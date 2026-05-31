import XCTest
@testable import UNBOUND

final class HsSkillTiersTests: XCTestCase {
    func testHsClusterHasAll14Skills() {
        XCTAssertEqual(HsSkillTiers.table.count, 14)
    }
    func testEveryHsSkillHasNineTiers() {
        for (id, tiers) in HsSkillTiers.table {
            XCTAssertEqual(tiers.count, 9, "\(id) missing tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(id) missing \(tier)")
            }
        }
    }
}
