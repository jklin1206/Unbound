import XCTest
@testable import UNBOUND

// Skill-tree redesign: NodeState collapsed 4-state (locked/attempting/achieved/
// mastered) → 2-state (locked/proven). Persisted `skillProgress` blobs predate
// the collapse and may hold any of the four legacy raw values. These tests lock
// the tolerant decoder so existing local saves decode without crashing on
// launch — there is no on-disk migration.
//
//   attempting        → locked   (prereqs met but target not yet hit)
//   achieved|mastered → proven   (target hit at least once)
//   locked/proven                round-trip unchanged
//   unknown raw value → locked   (safe fallback)

final class NodeStateLegacyDecodeTests: XCTestCase {

    private let dec = JSONDecoder()
    private let enc = JSONEncoder()

    // MARK: Legacy 4-state raw values decode into the 2-state model

    func testLegacyAttemptingDecodesToLocked() throws {
        XCTAssertEqual(try dec.decode(NodeState.self, from: Data("\"attempting\"".utf8)), .locked)
    }

    func testLegacyAchievedDecodesToProven() throws {
        XCTAssertEqual(try dec.decode(NodeState.self, from: Data("\"achieved\"".utf8)), .proven)
    }

    func testLegacyMasteredDecodesToProven() throws {
        XCTAssertEqual(try dec.decode(NodeState.self, from: Data("\"mastered\"".utf8)), .proven)
    }

    func testLegacyLockedDecodesToLocked() throws {
        XCTAssertEqual(try dec.decode(NodeState.self, from: Data("\"locked\"".utf8)), .locked)
    }

    func testCurrentProvenRoundTrips() throws {
        XCTAssertEqual(try dec.decode(NodeState.self, from: Data("\"proven\"".utf8)), .proven)
    }

    func testUnknownRawValueFoldsToLocked() throws {
        XCTAssertEqual(try dec.decode(NodeState.self, from: Data("\"garbage\"".utf8)), .locked)
    }

    func testEncodeRoundTrip() throws {
        for state in [NodeState.locked, .proven] {
            let data = try enc.encode(state)
            XCTAssertEqual(try dec.decode(NodeState.self, from: data), state)
        }
    }

    // MARK: A full legacy UserSkillProgress blob decodes cleanly

    func testLegacyUserSkillProgressBlobDecodes() throws {
        // Mirrors a real pre-redesign persisted blob: 4-state nodeStates, the
        // dropped `skillProgress` (currentLevel) dict, and the split
        // achievedAt/masteredAt timestamp maps that now merge into provenAt.
        let json = """
        {
          "userId": "u1",
          "nodeStates": {
            "a": "locked",
            "b": "attempting",
            "c": "achieved",
            "d": "mastered"
          },
          "achievedAt": { "c": 700000000.0, "d": 690000000.0 },
          "masteredAt": { "d": 695000000.0 },
          "skillProgress": {
            "c": { "currentLevel": 3, "xpInLevel": 40, "xpToNextLevel": 150 }
          },
          "updatedAt": 700000001.0
        }
        """
        let blob = try dec.decode(UserSkillProgress.self, from: Data(json.utf8))

        // States collapse correctly.
        XCTAssertEqual(blob.state(for: "a"), .locked)
        XCTAssertEqual(blob.state(for: "b"), .locked)   // attempting → locked
        XCTAssertEqual(blob.state(for: "c"), .proven)   // achieved  → proven
        XCTAssertEqual(blob.state(for: "d"), .proven)   // mastered  → proven
        XCTAssertEqual(blob.state(for: "missing"), .locked)

        // The dropped fake-XP `skillProgress` key is ignored (unknown to the
        // type now) and does not break decode.
        // achievedAt + masteredAt merge into provenAt, earliest timestamp wins.
        XCTAssertNotNil(blob.provenAt["c"])
        XCTAssertNotNil(blob.provenAt["d"])
        XCTAssertEqual(blob.provenAt["d"], Date(timeIntervalSinceReferenceDate: 690000000.0))
    }
}
