import XCTest
@testable import UNBOUND

final class PpSkillTiersTests: XCTestCase {
    func testPpClusterHasAll39Skills() {
        XCTAssertEqual(PpSkillTiers.table.count, 39)
    }
    func testEveryPpSkillHasNineTiers() {
        for (id, tiers) in PpSkillTiers.table {
            XCTAssertEqual(tiers.count, 9, "\(id) missing tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(id) missing \(tier)")
            }
        }
    }
}
