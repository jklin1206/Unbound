import XCTest
@testable import UNBOUND

final class OahSkillTiersTests: XCTestCase {
    func testOahClusterHasAll2Skills() {
        XCTAssertEqual(OahSkillTiers.table.count, 2)
    }
    func testEveryOahSkillHasNineTiers() {
        for (id, tiers) in OahSkillTiers.table {
            XCTAssertEqual(tiers.count, 9, "\(id) missing tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(id) missing \(tier)")
            }
        }
    }
}
