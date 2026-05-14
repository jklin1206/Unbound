import XCTest
@testable import UNBOUND

final class HspuSkillTiersTests: XCTestCase {
    func testHspuClusterHasAll10Skills() {
        XCTAssertEqual(HspuSkillTiers.table.count, 10)
    }
    func testEveryHspuSkillHasNineTiers() {
        for (id, tiers) in HspuSkillTiers.table {
            XCTAssertEqual(tiers.count, 9, "\(id) missing tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(id) missing \(tier)")
            }
        }
    }
}
