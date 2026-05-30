import XCTest
@testable import UNBOUND

final class CoSkillTiersTests: XCTestCase {
    func testCoClusterHasAll9Skills() {
        // 9 after collapsing the redundant dead-hang-45/60 split into one
        // dead-hang endurance node (F2 hold-seconds made the split dead weight).
        XCTAssertEqual(CoSkillTiers.table.count, 9)
    }
    func testEveryCoSkillHasNineTiers() {
        for (id, tiers) in CoSkillTiers.table {
            XCTAssertEqual(tiers.count, 9, "\(id) missing tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(id) missing \(tier)")
            }
        }
    }
}
