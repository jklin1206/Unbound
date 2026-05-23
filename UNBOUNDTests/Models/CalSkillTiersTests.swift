import XCTest
@testable import UNBOUND

final class CalSkillTiersTests: XCTestCase {

    func testCalClusterHasAll34Skills() {
        XCTAssertEqual(CalSkillTiers.table.count, 34,
                       "Expected 34 cal skills, found \(CalSkillTiers.table.count)")
    }

    func testEveryCalSkillHasNineTiers() {
        for (id, tiers) in CalSkillTiers.table {
            XCTAssertEqual(tiers.count, 9, "\(id) should have 9 tiers, has \(tiers.count)")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(id) missing tier .\(tier)")
            }
        }
    }
}
