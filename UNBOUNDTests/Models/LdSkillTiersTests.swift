import XCTest
@testable import UNBOUND

final class LdSkillTiersTests: XCTestCase {
    func testLdClusterHasAll34Skills() {
        XCTAssertEqual(LdSkillTiers.table.count, 34)
    }
    func testEveryLdSkillHasNineTiers() {
        for (id, tiers) in LdSkillTiers.table {
            XCTAssertEqual(tiers.count, 9, "\(id) missing tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(id) missing \(tier)")
            }
        }
    }
}
