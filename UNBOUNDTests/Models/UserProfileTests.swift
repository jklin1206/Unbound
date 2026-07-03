import XCTest
@testable import UNBOUND

final class UserProfileTests: XCTestCase {
    func testNewFieldsDefaultToUnset() {
        let p = UserProfile(id: "u", createdAt: Date(), onboardingCompleted: false, totalScans: 0)
        XCTAssertNil(p.trainingFeedbackMode)
        XCTAssertNil(p.trainingStyleOverride)
        XCTAssertNil(p.trainingDays)
        XCTAssertEqual(p.cutMode, CutMode())
    }

    func testCodableRoundtripWithNewFields() throws {
        var p = UserProfile(id: "u", createdAt: Date(timeIntervalSince1970: 1_700_000_000), onboardingCompleted: true, totalScans: 1)
        p.trainingFeedbackMode = .quick
        p.trainingStyleOverride = .hybrid
        p.trainingDays = [.monday, .wednesday, .friday]
        p.cutMode = CutMode(enabled: true, startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(decoded.trainingFeedbackMode, .quick)
        XCTAssertEqual(decoded.trainingStyleOverride, .hybrid)
        XCTAssertEqual(decoded.trainingDays, [.monday, .wednesday, .friday])
        XCTAssertTrue(decoded.cutMode.enabled)
    }

    func testDecodingLegacyProfileWithoutNewFieldsUsesDefaults() throws {
        // Simulate a stored profile from before this redesign — only the
        // original fields are present. All new fields should default cleanly.
        let legacyJSON = """
        {
            "id": "u",
            "createdAt": 1700000000,
            "onboardingCompleted": true,
            "totalScans": 2
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(UserProfile.self, from: legacyJSON)
        XCTAssertEqual(decoded.id, "u")
        XCTAssertNil(decoded.trainingFeedbackMode)
        XCTAssertNil(decoded.trainingStyleOverride)
        XCTAssertNil(decoded.trainingDays)
        XCTAssertEqual(decoded.cutMode, CutMode())
    }
}
