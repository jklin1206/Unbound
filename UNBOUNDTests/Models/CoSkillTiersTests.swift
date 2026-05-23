import XCTest
@testable import UNBOUND

final class CoSkillTiersTests: XCTestCase {
    func testCoClusterHasAll10Skills() {
        XCTAssertEqual(CoSkillTiers.table.count, 10)
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
