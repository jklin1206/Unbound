import XCTest
@testable import UNBOUND

final class PlSkillTiersTests: XCTestCase {
    func testPlClusterHasAll10Skills() {
        XCTAssertEqual(PlSkillTiers.table.count, 10)
    }
    func testEveryPlSkillHasNineTiers() {
        for (id, tiers) in PlSkillTiers.table {
            XCTAssertEqual(tiers.count, 9, "\(id) missing tiers")
            for tier in SkillTier.allCases {
                XCTAssertNotNil(tiers[tier], "\(id) missing \(tier)")
            }
        }
    }
}
