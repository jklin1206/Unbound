import XCTest
@testable import UNBOUND

final class PpSkillTiersTests: XCTestCase {
    func testPpClusterHasAll33Skills() {
        XCTAssertEqual(PpSkillTiers.table.count, 33)
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
