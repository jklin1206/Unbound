import XCTest
@testable import UNBOUND

final class UserSkillTierStateTests: XCTestCase {
    func testEmpty() {
        let state = UserSkillTierState.empty
        XCTAssertTrue(state.perSkill.isEmpty)
        XCTAssertEqual(state.rankUpsEarned, 0)
        XCTAssertTrue(state.ascendantSkills.isEmpty)
    }

    func testTierForUnknownSkillIsInitiate() {
        let state = UserSkillTierState.empty
        XCTAssertEqual(state.tier(for: "pp.pullup"), .initiate)
    }

    func testRoundtrip() throws {
        var state = UserSkillTierState.empty
        state.perSkill["pp.pullup"] = .vessel
        state.perSkill["ld.bw-front-squat"] = .forged
        state.rankUpsEarned = 12
        state.ascendantSkills = ["co.dead-hang-45"]
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(UserSkillTierState.self, from: data)
        XCTAssertEqual(decoded, state)
    }
}
