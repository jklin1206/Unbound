import XCTest
@testable import UNBOUND

final class ClSkillTiersTests: XCTestCase {
    func testClClusterHasAll32Skills() {
        XCTAssertEqual(ClSkillTiers.table.count, 32)
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
