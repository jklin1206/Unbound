import XCTest
@testable import UNBOUND

final class SkillTierTests: XCTestCase {
    func testOrdinalOrdering() {
        XCTAssertLessThan(SkillTier.initiate, SkillTier.novice)
        XCTAssertLessThan(SkillTier.vessel, SkillTier.unbound)
        XCTAssertLessThan(SkillTier.unbound, SkillTier.ascendant)
    }

    func testAllNineCases() {
        XCTAssertEqual(SkillTier.allCases.count, 9)
    }

    func testFlagshipMomentBoundary() {
        XCTAssertFalse(SkillTier.initiate.isFlagshipMoment)
        XCTAssertFalse(SkillTier.novice.isFlagshipMoment)
        XCTAssertFalse(SkillTier.apprentice.isFlagshipMoment)
        XCTAssertFalse(SkillTier.forged.isFlagshipMoment)
        XCTAssertFalse(SkillTier.veteran.isFlagshipMoment)
        XCTAssertFalse(SkillTier.master.isFlagshipMoment)
        XCTAssertTrue(SkillTier.vessel.isFlagshipMoment)
        XCTAssertTrue(SkillTier.unbound.isFlagshipMoment)
        XCTAssertTrue(SkillTier.ascendant.isFlagshipMoment)
    }

    func testDisplayNames() {
        XCTAssertEqual(SkillTier.initiate.displayName, "Initiate")
        XCTAssertEqual(SkillTier.unbound.displayName, "Unbound")
        XCTAssertEqual(SkillTier.ascendant.displayName, "Ascendant")
    }

    func testCodableRoundtrip() throws {
        for tier in SkillTier.allCases {
            let data = try JSONEncoder().encode(tier)
            let decoded = try JSONDecoder().decode(SkillTier.self, from: data)
            XCTAssertEqual(decoded, tier)
        }
    }
}
