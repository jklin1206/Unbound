import XCTest
@testable import UNBOUND

final class SquadRewardPolicyTests: XCTestCase {
    func testMissionPayoutConstant() {
        XCTAssertEqual(SquadRewardPolicy.missionArcs, 300)
        XCTAssertEqual(SquadRewardPolicy.duelWinArcs, 120)
    }

    func testSourceIds() {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        // uuidString on Apple platforms returns uppercase; lowercased() normalises it.
        XCTAssertEqual(SquadRewardPolicy.missionSourceId(id), "squad_mission:11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(SquadRewardPolicy.duelSourceId(id), "friend_challenge:11111111-1111-1111-1111-111111111111")
    }

    func testSourceIdsAreLowercased() {
        // UUIDs with mixed-hex letters must be normalised to lowercase.
        let id = UUID(uuidString: "ABCDEF12-3456-7890-ABCD-EF1234567890")!
        let missionId = SquadRewardPolicy.missionSourceId(id)
        let duelId = SquadRewardPolicy.duelSourceId(id)
        XCTAssertEqual(missionId, missionId.lowercased(), "missionSourceId must be fully lowercase")
        XCTAssertEqual(duelId, duelId.lowercased(), "duelSourceId must be fully lowercase")
    }

    func testSourceIdPrefixes() {
        let id = UUID()
        XCTAssertTrue(SquadRewardPolicy.missionSourceId(id).hasPrefix("squad_mission:"))
        XCTAssertTrue(SquadRewardPolicy.duelSourceId(id).hasPrefix("friend_challenge:"))
    }
}
