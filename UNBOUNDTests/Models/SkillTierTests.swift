import XCTest
@testable import UNBOUND

final class SkillTierTests: XCTestCase {
    func testOrdinalOrdering() {
        XCTAssertLessThan(SkillTier.initiate, SkillTier.novice)
        XCTAssertLessThan(SkillTier.vessel, SkillTier.ascendant)
        XCTAssertLessThan(SkillTier.ascendant, SkillTier.unbound)
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
        XCTAssertTrue(SkillTier.ascendant.isFlagshipMoment)
        XCTAssertTrue(SkillTier.unbound.isFlagshipMoment)
    }

    func testDisplayNames() {
        XCTAssertEqual(SkillTier.initiate.displayName, "Initiate")
        // Brand swap: peak (.unbound, rawValue 8) is labeled "Unbound";
        // tier 7 (.ascendant) is labeled "Ascendant". Case names kept; label-only.
        XCTAssertEqual(SkillTier.ascendant.displayName, "Ascendant")
        XCTAssertEqual(SkillTier.unbound.displayName, "Unbound")
    }

    func testCodableRoundtrip() throws {
        for tier in SkillTier.allCases {
            let data = try JSONEncoder().encode(tier)
            let decoded = try JSONDecoder().decode(SkillTier.self, from: data)
            XCTAssertEqual(decoded, tier)
        }
    }
}
