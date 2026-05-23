import XCTest
@testable import UNBOUND

final class ClSkillTiersTests: XCTestCase {
    func testClClusterHasAll37Skills() {
        XCTAssertEqual(ClSkillTiers.table.count, 37)
    }
    func testEveryClSkillHasNineTiers() {
        for (id, tiers) in ClSkillTiers.table {
            XCTAssertEqual(tiers.count, 9, "\(id) missing tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(id) missing \(tier)")
            }
        }
    }
}
