import XCTest
@testable import UNBOUND

final class WeeklyHonorTests: XCTestCase {
    func testCodableRoundtrip() throws {
        let h = WeeklyHonor(
            id: UUID(),
            squadId: UUID(),
            weekIso: "2026-W20",
            kind: .ironWill,
            recipientUserId: UUID(),
            awardedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(h)
        let decoded = try JSONDecoder().decode(WeeklyHonor.self, from: data)
        XCTAssertEqual(decoded, h)
    }

    func testAllKindsHaveDisplayName() {
        for kind in WeeklyHonor.Kind.allCases {
            XCTAssertFalse(kind.displayName.isEmpty)
            XCTAssertFalse(kind.reason.isEmpty)
            XCTAssertFalse(kind.iconName.isEmpty)
        }
    }

    func testAllNineKindsPresent() {
        XCTAssertEqual(WeeklyHonor.Kind.allCases.count, 9)
    }

    func testLegacyTrialFinisherDecodesAsVowFinisher() throws {
        let decoded = try JSONDecoder().decode(WeeklyHonor.Kind.self, from: Data(#""trialFinisher""#.utf8))
        XCTAssertEqual(decoded, .vowFinisher)
        XCTAssertEqual(decoded.displayName, "Binding Vow Finisher")
    }
}
